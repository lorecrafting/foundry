defmodule Foundry.DurableStore.Protected.Operations do
  @moduledoc false

  alias Foundry.DurableStore.{Database, Encoding}

  # Reopen-ready invariant: Operations writes states validated by RestartCheck and TransitionReplay.
  import Foundry.DurableStore.Protected.Rows
  import Foundry.DurableStore.Protected.Guards

  @closed_reservation_statuses ~w(consumed released retired)
  @closed_effect_statuses Foundry.DurableStore.Protected.Rows.closed_effect_statuses()
  @dimensions Foundry.DurableStore.Protected.Guards.dimensions()

  @doc false
  def persist_nonstart_settlement(conn, operation, facts) do
    effect = facts["effect"]
    claim = facts["claim"]
    receipt = facts["receipt"]
    payload = operation["payload"]

    with "non_started" <- operation["outcome"],
         true <- is_map(effect) and is_map(claim) and is_map(receipt),
         true <- receipt["outcome"] == "non_started",
         true <- receipt["claim_id"] == claim["claim_id"],
         failure_class when is_binary(failure_class) and failure_class != "" <-
           payload["failure_class"],
         role when role in ~w(developer reviewer pm check freeze build integration activation) <-
           effect["role"],
         work_owner when is_binary(work_owner) and work_owner != "" <- effect["assignment_id"],
         generation when is_integer(generation) and generation >= 0 <- effect["phase_generation"],
         {:ok, existing} <- existing_infrastructure_settlement(conn, effect["effect_id"]),
         {:ok, [[prior_count]]} <-
           Database.query(
             conn,
             "SELECT count(*) FROM root_infrastructure_settlements WHERE role = ? AND work_owner = ? AND infrastructure_generation = ?",
             [role, work_owner, generation]
           ),
         ordinal <- if(existing == :absent, do: prior_count + 1, else: existing["ordinal"]),
         :ok <-
           if(existing == :absent,
             do:
               validate_nonstart_predecessor(
                 conn,
                 effect,
                 role,
                 work_owner,
                 generation,
                 ordinal
               ),
             else: :ok
           ),
         state <- %{
           "schema_version" => 1,
           "effect_id" => effect["effect_id"],
           "claim_id" => claim["claim_id"],
           "receipt_id" => receipt["receipt_id"],
           "role" => role,
           "work_owner" => work_owner,
           "infrastructure_generation" => generation,
           "predecessor_effect_id" => effect["predecessor_effect_id"],
           "failure_class" => failure_class,
           "ordinal" => ordinal
         },
         {:ok, state} <- persist_or_match_infrastructure_settlement(conn, existing, state) do
      {:ok, state}
    else
      _ -> {:error, :invalid_nonstart_infrastructure_settlement}
    end
  end

  defp existing_infrastructure_settlement(conn, effect_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT state FROM root_infrastructure_settlements WHERE effect_id = ?",
             [effect_id]
           ) do
      case rows do
        [] -> {:ok, :absent}
        [[bytes]] -> decode(bytes)
        _ -> {:error, :duplicate_infrastructure_settlement}
      end
    end
  end

  defp persist_or_match_infrastructure_settlement(conn, :absent, state) do
    with {:ok, bytes} <- encode(state),
         :ok <-
           Database.execute(
             conn,
             "INSERT INTO root_infrastructure_settlements(effect_id, claim_id, receipt_id, role, work_owner, infrastructure_generation, predecessor_effect_id, failure_class, ordinal, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
             [
               state["effect_id"],
               state["claim_id"],
               state["receipt_id"],
               state["role"],
               state["work_owner"],
               state["infrastructure_generation"],
               state["predecessor_effect_id"],
               state["failure_class"],
               state["ordinal"],
               {:blob, bytes}
             ]
           ) do
      {:ok, state}
    end
  end

  defp persist_or_match_infrastructure_settlement(_conn, existing, state)
       when existing == state,
       do: {:ok, Map.put(state, "duplicate", true)}

  defp persist_or_match_infrastructure_settlement(_conn, _existing, _state),
    do: {:error, :invalid_nonstart_infrastructure_settlement}

  defp validate_nonstart_predecessor(
         _conn,
         %{"predecessor_effect_id" => nil},
         _role,
         _owner,
         _generation,
         1
       ),
       do: :ok

  defp validate_nonstart_predecessor(conn, effect, role, owner, generation, ordinal) do
    with predecessor when is_binary(predecessor) <- effect["predecessor_effect_id"],
         {:ok, [[^role, ^owner, ^generation, prior_ordinal]]} <-
           Database.query(
             conn,
             "SELECT role, work_owner, infrastructure_generation, ordinal FROM root_infrastructure_settlements WHERE effect_id = ?",
             [predecessor]
           ),
         true <- prior_ordinal + 1 == ordinal do
      :ok
    else
      _ -> {:error, :invalid_nonstart_predecessor}
    end
  end

  def apply_operation(conn, %{"type" => "set_policy"} = operation) do
    upsert_simple_root(conn, "root_policies", "policy_id", operation["policy_id"], operation)
  end

  def apply_operation(conn, %{"type" => "set_control"} = operation) do
    with {:ok, facts} <-
           upsert_simple_root(
             conn,
             "root_controls",
             "control_id",
             operation["control_id"],
             operation
           ),
         {:ok, {outstanding, ledgers}} <-
           fence_control_descendants(conn, operation["control_id"], operation["value"]) do
      {:ok, Map.merge(facts, %{"outstanding_claim_ids" => outstanding, "ledgers" => ledgers})}
    else
      {:error, :invalid_control_state} -> {:reject, :invalid_control_state, %{}}
      # A cascaded cancel's refusal refuses the whole command (live_refusal_probe_test.exs).
      {:reject, _reason, _facts} = reject -> reject
      {:error, _reason} = error -> error
    end
  end

  def apply_operation(conn, %{"type" => "append_inbox"} = operation) do
    with :ok <-
           exact_keys(
             operation,
             ~w(type execution_id sequence item_kind payload authenticated_actor)
           ),
         :ok <- identities(operation, ~w(execution_id item_kind)),
         true <- operation["item_kind"] in ~w(result exit observation),
         sequence when is_integer(sequence) and sequence > 0 <- operation["sequence"],
         true <- plain_value?(operation["payload"]),
         {:ok, digest} <-
           Encoding.semantic_digest("foundry-authenticated-inbox-item-v1", %{
             "execution_id" => operation["execution_id"],
             "sequence" => sequence,
             "item_kind" => operation["item_kind"],
             "payload" => operation["payload"]
           }),
         {:ok, current} <- load_inbox(conn, operation["execution_id"]),
         {:ok, disposition} <- inbox_append_guard(current, sequence),
         :ok <- inbox_independence(conn, current, operation),
         {:ok, item_bytes} <-
           encode(%{
             "schema_version" => 1,
             "execution_id" => operation["execution_id"],
             "sequence" => sequence,
             "item_kind" => operation["item_kind"],
             "disposition" => disposition,
             "item_digest" => digest,
             "payload" => operation["payload"]
           }),
         :ok <-
           write_inbox_head(
             conn,
             current,
             operation["execution_id"],
             operation["authenticated_actor"],
             sequence
           ),
         :ok <-
           Database.execute(
             conn,
             "INSERT INTO authenticated_inbox_items(execution_id, sequence, item_kind, disposition, item_digest, item) VALUES (?, ?, ?, ?, ?, ?)",
             [
               operation["execution_id"],
               sequence,
               operation["item_kind"],
               disposition,
               digest,
               {:blob, item_bytes}
             ]
           ),
         {:ok, fact} <- inbox_fact(conn, operation["execution_id"]) do
      {:ok, %{"inbox" => fact}}
    else
      false ->
        {:reject, :invalid_inbox_item, %{}}

      {:error, reason}
      when reason in [:inbox_sequence_conflict, :inbox_actor_conflict, :principal_not_independent] ->
        {:reject, reason, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :invalid_inbox_item, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "seal_inbox"} = operation) do
    with :ok <- exact_keys(operation, ~w(type execution_id last_sequence authenticated_actor)),
         :ok <- identity(operation["execution_id"]),
         last when is_integer(last) and last >= 0 <- operation["last_sequence"],
         {:ok, %{last_sequence: ^last, sealed_sequence: nil} = inbox} <-
           load_existing_inbox(conn, operation["execution_id"]),
         true <- inbox.actor_id == operation["authenticated_actor"],
         next <- %{inbox | revision: inbox.revision + 1, sealed_sequence: last},
         {:ok, bytes} <- encode(inbox_state(operation["execution_id"], next)),
         :ok <-
           Database.execute(
             conn,
             "UPDATE authenticated_inboxes SET revision = ?, sealed_sequence = ?, state = ? WHERE execution_id = ? AND revision = ? AND sealed_sequence IS NULL",
             [next.revision, last, {:blob, bytes}, operation["execution_id"], inbox.revision]
           ),
         {:ok, [[1]]} <- Database.query(conn, "SELECT changes()"),
         {:ok, fact} <- inbox_fact(conn, operation["execution_id"]) do
      {:ok, %{"inbox" => fact}}
    else
      {:ok, %{sealed_sequence: sealed}} when not is_nil(sealed) ->
        {:reject, :inbox_already_sealed, %{}}

      {:ok, _inbox} ->
        {:reject, :inbox_sequence_conflict, %{}}

      {:error, :not_found} ->
        {:reject, :inbox_not_found, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :invalid_inbox_seal, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "grant_ledger"} = operation) do
    with :ok <- exact_keys(operation, ~w(type ledger_id generation dimension units)),
         :ok <- identity(operation["ledger_id"]),
         generation when is_integer(generation) and generation >= 0 <- operation["generation"],
         dimension when dimension in @dimensions <- operation["dimension"],
         units when is_integer(units) and units >= 0 <- operation["units"],
         {:ok, :absent} <- load_ledger(conn, operation["ledger_id"], generation),
         ledger <- %{
           ledger_id: operation["ledger_id"],
           generation: generation,
           parent_ledger_id: nil,
           parent_generation: nil,
           dimension: dimension,
           revision: 0,
           status: "open",
           authorized: units,
           available: units,
           held: 0,
           consumed: 0,
           delegated: 0,
           retired: 0
         },
         :ok <- insert_ledger(conn, ledger) do
      {:ok, %{"ledger" => public_ledger(ledger)}}
    else
      {:ok, _existing} -> {:reject, :ledger_exists, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :invalid_ledger_grant, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "delegate_allocation"} = operation) do
    keys =
      ~w(type parent_ledger_id parent_generation child_ledger_id child_generation dimension units)

    with :ok <- exact_keys(operation, keys),
         :ok <- identities(operation, ~w(parent_ledger_id child_ledger_id)),
         true <- operation["parent_ledger_id"] != operation["child_ledger_id"],
         {:ok, parent} <-
           load_existing_ledger(
             conn,
             operation["parent_ledger_id"],
             operation["parent_generation"]
           ),
         "open" <- parent.status,
         true <- parent.dimension == operation["dimension"],
         units when is_integer(units) and units > 0 and units <= parent.available <-
           operation["units"],
         {:ok, :absent} <-
           load_ledger(conn, operation["child_ledger_id"], operation["child_generation"]),
         next_parent <- %{
           parent
           | revision: parent.revision + 1,
             available: parent.available - units,
             delegated: parent.delegated + units
         },
         child <- %{
           ledger_id: operation["child_ledger_id"],
           generation: operation["child_generation"],
           parent_ledger_id: parent.ledger_id,
           parent_generation: parent.generation,
           dimension: parent.dimension,
           revision: 0,
           status: "open",
           authorized: units,
           available: units,
           held: 0,
           consumed: 0,
           delegated: 0,
           retired: 0
         },
         :ok <- update_ledger(conn, parent, next_parent),
         :ok <- insert_ledger(conn, child) do
      {:ok,
       %{
         "parent_ledger" => public_ledger(next_parent),
         "child_ledger" => public_ledger(child)
       }}
    else
      {:ok, _existing} -> {:reject, :child_ledger_exists, %{}}
      {:error, :not_found} -> {:reject, :parent_ledger_not_found, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :allocation_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "return_allocation"} = operation) do
    keys = ~w(type child_ledger_id child_generation units)

    with :ok <- exact_keys(operation, keys),
         :ok <- identity(operation["child_ledger_id"]),
         {:ok, child} <-
           load_existing_ledger(
             conn,
             operation["child_ledger_id"],
             operation["child_generation"]
           ),
         parent_id when is_binary(parent_id) <- child.parent_ledger_id,
         {:ok, parent} <- load_existing_ledger(conn, parent_id, child.parent_generation),
         "open" <- child.status,
         "open" <- parent.status,
         units when is_integer(units) and units > 0 and units <= child.available <-
           operation["units"],
         0 <- child.held,
         0 <- child.delegated,
         next_child <- %{
           child
           | revision: child.revision + 1,
             authorized: child.authorized - units,
             available: child.available - units
         },
         next_parent <- %{
           parent
           | revision: parent.revision + 1,
             delegated: parent.delegated - units,
             available: parent.available + units
         },
         true <- next_parent.delegated >= 0,
         :ok <- update_ledger(conn, child, next_child),
         :ok <- update_ledger(conn, parent, next_parent) do
      {:ok,
       %{
         "parent_ledger" => public_ledger(next_parent),
         "child_ledger" => public_ledger(next_child)
       }}
    else
      {:error, :not_found} -> {:reject, :ledger_not_found, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :allocation_return_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "reserve"} = operation) do
    keys = ~w(type reservation_id ledger_id generation owner_kind owner_id units)

    with :ok <- exact_keys(operation, keys),
         :ok <- identities(operation, ~w(reservation_id ledger_id owner_kind owner_id)),
         {:ok, ledger} <-
           load_existing_ledger(conn, operation["ledger_id"], operation["generation"]),
         "open" <- ledger.status,
         units when is_integer(units) and units > 0 and units <= ledger.available <-
           operation["units"],
         {:ok, []} <-
           Database.query(
             conn,
             "SELECT reservation_id FROM root_reservations WHERE reservation_id = ?",
             [operation["reservation_id"]]
           ),
         :ok <- owner_not_created(conn, operation["owner_id"]),
         reservation <- %{
           reservation_id: operation["reservation_id"],
           ledger_id: ledger.ledger_id,
           generation: ledger.generation,
           dimension: ledger.dimension,
           owner_kind: operation["owner_kind"],
           owner_id: operation["owner_id"],
           units: units,
           revision: 0,
           status: "proposed",
           claim_id: nil
         },
         :ok <- insert_reservation(conn, reservation) do
      {:ok,
       %{
         "ledger" => public_ledger(ledger),
         "reservation" => public_reservation(reservation)
       }}
    else
      {:error, :not_found} -> {:reject, :ledger_not_found, %{}}
      {:error, :reservation_owner_exists} -> {:reject, :reservation_owner_exists, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :reservation_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "release_reservation"} = operation) do
    with :ok <- exact_keys(operation, ~w(type reservation_id proof)),
         "unissued" <- operation["proof"],
         {:ok, reservation} <- load_reservation(conn, operation["reservation_id"]),
         true <- reservation.status in ["proposed", "reserved", "issued_unknown"],
         :ok <- release_guard(conn, reservation),
         {:ok, ledger} <-
           load_existing_ledger(conn, reservation.ledger_id, reservation.generation),
         target <- if(ledger.status == "open", do: "released", else: "retired"),
         next_reservation <- %{
           reservation
           | revision: reservation.revision + 1,
             status: target
         },
         next_ledger <-
           if(reservation.status == "proposed",
             do: ledger,
             else: release_hold(ledger, reservation.units)
           ),
         :ok <- update_reservation(conn, reservation, next_reservation),
         :ok <- maybe_update_ledger(conn, ledger, next_ledger) do
      {:ok,
       %{
         "ledger" => public_ledger(next_ledger),
         "reservation" => public_reservation(next_reservation)
       }}
    else
      {:error, :not_found} ->
        {:reject, :reservation_not_found, %{}}

      {:error, reason} when reason in [:claim_already_issued, :unissued_proof_required] ->
        {:reject, reason, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :reservation_release_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "close_generation"} = operation) do
    with :ok <- exact_keys(operation, ~w(type ledger_id generation)),
         {:ok, ledgers} <-
           subtree_ledgers(conn, operation["ledger_id"], operation["generation"]),
         {:ok, %{"status" => "open"}} <-
           ledger_fact(conn, operation["ledger_id"], operation["generation"]),
         :ok <- close_subtree(conn, ledgers),
         {:ok, closed} <-
           subtree_ledgers(conn, operation["ledger_id"], operation["generation"]) do
      {:ok, %{"ledgers" => Enum.map(closed, &public_ledger/1)}}
    else
      {:error, :not_found} -> {:reject, :ledger_not_found, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :generation_already_closed, %{}}
    end
  end

  def apply_operation(
        conn,
        %{"type" => "reset_generation", "parent_ledger_id" => nil} = operation
      ) do
    keys =
      ~w(type ledger_id old_generation new_generation parent_ledger_id parent_generation units)

    old_generation = operation["old_generation"]

    with :ok <- exact_keys(operation, keys),
         nil <- operation["parent_generation"],
         true <- operation["new_generation"] == old_generation + 1,
         {:ok, old} <- load_existing_ledger(conn, operation["ledger_id"], old_generation),
         nil <- old.parent_ledger_id,
         "open" <- old.status,
         {:ok, ^old_generation} <- current_generation(conn, old.ledger_id),
         units when is_integer(units) and units >= 0 and units <= old.available <-
           operation["units"],
         {:ok, :absent} <-
           load_ledger(conn, operation["ledger_id"], operation["new_generation"]),
         {:ok, subtree} <- subtree_ledgers(conn, old.ledger_id, old.generation),
         :ok <- close_subtree(conn, subtree),
         {:ok, closed_subtree} <- subtree_ledgers(conn, old.ledger_id, old.generation),
         {:ok, closed} <- load_existing_ledger(conn, old.ledger_id, old.generation),
         fresh <- %{
           ledger_id: old.ledger_id,
           generation: operation["new_generation"],
           parent_ledger_id: nil,
           parent_generation: nil,
           dimension: old.dimension,
           revision: 0,
           status: "open",
           authorized: units,
           available: units,
           held: 0,
           consumed: 0,
           delegated: 0,
           retired: 0
         },
         :ok <- insert_ledger(conn, fresh) do
      {:ok,
       %{
         "closed_generation" => public_ledger(closed),
         "new_generation" => public_ledger(fresh),
         "ledgers" => Enum.map(closed_subtree, &public_ledger/1),
         "transfer_kind" => "explicit_root_reset_unused_authority"
       }}
    else
      {:ok, _existing} -> {:reject, :new_generation_exists, %{}}
      {:error, :not_found} -> {:reject, :ledger_not_found, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :generation_reset_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "reset_generation"} = operation) do
    keys =
      ~w(type ledger_id old_generation new_generation parent_ledger_id parent_generation units)

    old_generation = operation["old_generation"]

    with :ok <- exact_keys(operation, keys),
         true <- operation["new_generation"] == old_generation + 1,
         {:ok, old} <-
           load_existing_ledger(conn, operation["ledger_id"], old_generation),
         "open" <- old.status,
         {:ok, ^old_generation} <- current_generation(conn, old.ledger_id),
         true <- old.parent_ledger_id == operation["parent_ledger_id"],
         true <- old.parent_generation == operation["parent_generation"],
         {:ok, parent} <-
           load_existing_ledger(conn, old.parent_ledger_id, old.parent_generation),
         "open" <- parent.status,
         units when is_integer(units) and units >= 0 and units <= parent.available <-
           operation["units"],
         {:ok, :absent} <-
           load_ledger(conn, operation["ledger_id"], operation["new_generation"]),
         {:ok, subtree} <- subtree_ledgers(conn, old.ledger_id, old.generation),
         :ok <- close_subtree(conn, subtree),
         {:ok, closed_subtree} <- subtree_ledgers(conn, old.ledger_id, old.generation),
         {:ok, closed} <- load_existing_ledger(conn, old.ledger_id, old.generation),
         next_parent <- %{
           parent
           | revision: parent.revision + 1,
             available: parent.available - units,
             delegated: parent.delegated + units
         },
         fresh <- %{
           ledger_id: old.ledger_id,
           generation: operation["new_generation"],
           parent_ledger_id: parent.ledger_id,
           parent_generation: parent.generation,
           dimension: old.dimension,
           revision: 0,
           status: "open",
           authorized: units,
           available: units,
           held: 0,
           consumed: 0,
           delegated: 0,
           retired: 0
         },
         :ok <- update_ledger(conn, parent, next_parent),
         :ok <- insert_ledger(conn, fresh) do
      {:ok,
       %{
         "closed_generation" => public_ledger(closed),
         "new_generation" => public_ledger(fresh),
         "parent_ledger" => public_ledger(next_parent),
         "ledgers" => Enum.map(closed_subtree, &public_ledger/1)
       }}
    else
      {:ok, _existing} -> {:reject, :new_generation_exists, %{}}
      {:error, :not_found} -> {:reject, :ledger_not_found, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :generation_reset_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "create_effect"} = operation) do
    keys =
      ~w(type effect_id request operation scope ticket_id attempt_id execution_id policy_id policy_revision control_id control_revision reservation_ids leases authenticated_actor)

    with :ok <- exact_keys(operation, keys),
         :ok <-
           identities(
             operation,
             ~w(effect_id operation scope ticket_id attempt_id execution_id policy_id control_id)
           ),
         true <- plain_map?(operation["request"]),
         :ok <- identities(operation["request"], ~w(request_id role)),
         :ok <- identity(operation["authenticated_actor"]),
         phase_generation when is_integer(phase_generation) and phase_generation >= 0 <-
           Map.get(operation["request"], "phase_generation", 0),
         operation_ordinal when is_integer(operation_ordinal) and operation_ordinal >= 0 <-
           Map.get(operation["request"], "operation_ordinal", 0),
         predecessor_effect_id <- operation["request"]["predecessor_effect_id"],
         :ok <- attempt_open(conn, operation["ticket_id"], operation["attempt_id"]),
         :ok <- semantic_effect_available(conn, operation),
         :ok <-
           predecessor_guard(
             conn,
             operation,
             phase_generation,
             operation_ordinal,
             predecessor_effect_id
           ),
         {:ok, request_digest} <-
           Encoding.semantic_digest("foundry-effect-request-v1", %{
             "effect_id" => operation["effect_id"],
             "operation" => operation["operation"],
             "scope" => operation["scope"],
             "ticket_id" => operation["ticket_id"],
             "attempt_id" => operation["attempt_id"],
             "execution_id" => operation["execution_id"],
             "request" => operation["request"]
           }),
         true <- proper_list?(operation["reservation_ids"]),
         true <- proper_list?(operation["leases"]),
         {:ok, policy} <- load_simple(conn, "root_policies", "policy_id", operation["policy_id"]),
         {:ok, control} <-
           load_simple(conn, "root_controls", "control_id", operation["control_id"]),
         true <- policy.revision == operation["policy_revision"],
         true <- control.revision == operation["control_revision"],
         :ok <- allowed_effect?(policy.value, control.value, operation),
         {:ok, own_inbox} <- load_inbox(conn, operation["execution_id"]),
         :ok <-
           principal_independence(
             conn,
             policy.value,
             operation["ticket_id"],
             operation["attempt_id"],
             operation["request"]["role"],
             [operation["authenticated_actor"] | inbox_principals(own_inbox)]
           ),
         :ok <- nonstart_allowance(conn, policy.value, operation),
         {:ok, reservations} <- load_effect_reservations(conn, operation),
         :ok <- all_owned_listed(conn, operation["effect_id"], reservations),
         :ok <- reservation_dimensions(operation, reservations),
         {:ok, lease_specs} <- normalize_lease_specs(operation["leases"]),
         :ok <- lease_specs_available(conn, lease_specs),
         {:ok, []} <-
           Database.query(conn, "SELECT effect_id FROM root_effects WHERE effect_id = ?", [
             operation["effect_id"]
           ]),
         effect <- %{
           effect_id: operation["effect_id"],
           request_digest: request_digest,
           policy_id: operation["policy_id"],
           policy_revision: operation["policy_revision"],
           control_id: operation["control_id"],
           control_revision: operation["control_revision"],
           operation: operation["operation"],
           scope: operation["scope"],
           ticket_id: operation["ticket_id"],
           attempt_id: operation["attempt_id"],
           execution_id: operation["execution_id"],
           assignment_id:
             assignment_id(
               operation["ticket_id"],
               operation["attempt_id"],
               operation["request"]["role"]
             ),
           role: operation["request"]["role"],
           phase_generation: phase_generation,
           operation_ordinal: operation_ordinal,
           predecessor_effect_id: predecessor_effect_id,
           request_id: operation["request"]["request_id"],
           issuer: operation["authenticated_actor"],
           channel: "protected-gateway",
           profile: Map.get(operation["request"], "profile", "unspecified"),
           deadline: Map.get(operation["request"], "deadline"),
           status: "pending",
           revision: 0,
           reservation_ids: Enum.map(reservations, & &1.reservation_id)
         },
         :ok <- insert_effect(conn, effect),
         {:ok, activated_reservations} <- activate_reservations(conn, reservations),
         :ok <- insert_pending_leases(conn, operation["effect_id"], lease_specs),
         {:ok, ledgers} <- ledger_facts_for_reservations(conn, activated_reservations) do
      {:ok,
       %{
         "effect" => public_effect(effect),
         "reservations" => Enum.map(activated_reservations, &public_reservation/1),
         "ledgers" => ledgers,
         "lease_specs" => lease_specs
       }}
    else
      {:error, reason}
      when reason in [
             :policy_not_found,
             :control_not_found,
             :effect_not_allowed,
             :control_not_active,
             :reservation_not_found,
             :reservation_owner_mismatch,
             :reservation_not_held,
             :reservation_activation_not_permitted,
             :lease_conflict,
             :duplicate_semantic_operation,
             :duplicate_request_identity,
             :operation_dimension_mismatch,
             :reservation_ledger_mismatch,
             :unlisted_owned_reservation,
             :nonstart_allowance_exhausted,
             :predecessor_not_terminal,
             :predecessor_identity_mismatch,
             :attempt_closed,
             :principal_not_independent
           ] ->
        {:reject, reason, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :invalid_effect_request, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "claim_effect"} = operation) do
    with :ok <-
           exact_keys(
             operation,
             ~w(type effect_id claim_id writer_epoch current_writer_epoch)
           ),
         :ok <- identities(operation, ~w(effect_id claim_id writer_epoch)),
         true <- operation["writer_epoch"] == operation["current_writer_epoch"],
         {:ok, effect} <- load_effect(conn, operation["effect_id"]),
         "pending" <- effect.status,
         {:ok, policy} <- load_simple(conn, "root_policies", "policy_id", effect.policy_id),
         {:ok, control} <- load_simple(conn, "root_controls", "control_id", effect.control_id),
         true <- policy.revision == effect.policy_revision,
         true <- control.revision == effect.control_revision,
         :ok <- control_active?(control.value),
         :ok <- predecessor_current?(conn, effect),
         {:ok, reservations} <- reservations_for_effect(conn, effect.effect_id),
         true <- reservations != [],
         true <- Enum.all?(reservations, &(&1.status == "reserved" and is_nil(&1.claim_id))),
         :ok <- reservations_open?(conn, reservations),
         :ok <- lease_specs_available(conn, effect.lease_specs),
         # root_claims is keyed on claim_id: a reused id is a refusal, not a storage error
         # (live_refusal_probe_test.exs, L2).
         {:ok, []} <-
           Database.query(conn, "SELECT claim_id FROM root_claims WHERE claim_id = ?", [
             operation["claim_id"]
           ]),
         claim <- %{
           claim_id: operation["claim_id"],
           effect_id: effect.effect_id,
           writer_epoch: operation["writer_epoch"],
           status: "claimed",
           revision: 0
         },
         next_effect <- %{effect | status: "claimed", revision: effect.revision + 1},
         :ok <- insert_claim(conn, claim),
         :ok <- bind_reservations_to_claim(conn, reservations, claim.claim_id),
         :ok <- update_effect(conn, effect, next_effect),
         :ok <- materialize_leases(conn, effect.effect_id, claim.claim_id) do
      {:ok,
       %{
         "claim" => public_claim(claim),
         "effect" => public_effect(next_effect)
       }}
    else
      {:error, :not_found} ->
        {:reject, :effect_not_found, %{}}

      {:ok, [_ | _]} ->
        {:reject, :claim_id_in_use, %{}}

      {:error, reason}
      when reason in [
             :control_not_active,
             :predecessor_not_terminal,
             :ledger_closed,
             :ledger_generation_superseded,
             :lease_conflict
           ] ->
        {:reject, reason, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :claim_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "issue_claim"} = operation) do
    with :ok <- exact_keys(operation, ~w(type claim_id writer_epoch current_writer_epoch)),
         {:ok, claim} <- load_claim(conn, operation["claim_id"]),
         "claimed" <- claim.status,
         true <- claim.writer_epoch == operation["writer_epoch"],
         true <- claim.writer_epoch == operation["current_writer_epoch"],
         {:ok, effect} <- load_effect(conn, claim.effect_id),
         "claimed" <- effect.status,
         {:ok, policy} <- load_simple(conn, "root_policies", "policy_id", effect.policy_id),
         {:ok, control} <- load_simple(conn, "root_controls", "control_id", effect.control_id),
         true <- policy.revision == effect.policy_revision,
         true <- control.revision == effect.control_revision,
         :ok <- control_active?(control.value),
         :ok <- predecessor_current?(conn, effect),
         {:ok, reservations} <- reservations_for_claim(conn, claim.claim_id),
         true <- reservations != [] and Enum.all?(reservations, &(&1.status == "reserved")),
         :ok <- reservations_open?(conn, reservations),
         next_claim <- %{claim | status: "issued", revision: claim.revision + 1},
         next_effect <- %{effect | status: "issued", revision: effect.revision + 1},
         :ok <- update_claim(conn, claim, next_claim),
         :ok <- update_effect(conn, effect, next_effect),
         :ok <- update_reservation_statuses(conn, reservations, "issued_unknown") do
      {:ok,
       %{
         "claim" => public_claim(next_claim),
         "effect" => public_effect(next_effect)
       }}
    else
      {:error, :not_found} ->
        {:reject, :claim_not_found, %{}}

      {:error, :control_not_active} ->
        {:reject, :control_not_active, %{}}

      {:error, :predecessor_not_terminal} ->
        {:reject, :predecessor_not_terminal, %{}}

      {:error, :ledger_closed} ->
        {:reject, :ledger_closed, %{}}

      {:error, :ledger_generation_superseded} ->
        {:reject, :ledger_generation_superseded, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :claim_issue_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "reclaim_claim"} = operation) do
    keys =
      ~w(type claim_id prior_writer_epoch new_writer_epoch proof current_writer_epoch)

    with :ok <- exact_keys(operation, keys),
         :ok <- identities(operation, ~w(claim_id prior_writer_epoch new_writer_epoch proof)),
         "issuer_quiescent" <- operation["proof"],
         true <- operation["new_writer_epoch"] == operation["current_writer_epoch"],
         true <- operation["prior_writer_epoch"] != operation["new_writer_epoch"],
         {:ok, claim} <- load_claim(conn, operation["claim_id"]),
         "claimed" <- claim.status,
         true <- claim.writer_epoch == operation["prior_writer_epoch"],
         {:ok, effect} <- load_effect(conn, claim.effect_id),
         "claimed" <- effect.status,
         {:ok, control} <- load_simple(conn, "root_controls", "control_id", effect.control_id),
         true <- control.revision == effect.control_revision,
         :ok <- control_active?(control.value),
         {:ok, reservations} <- reservations_for_claim(conn, claim.claim_id),
         :ok <- reservations_open?(conn, reservations),
         next <- %{
           claim
           | writer_epoch: operation["new_writer_epoch"],
             revision: claim.revision + 1
         },
         :ok <- update_claim(conn, claim, next) do
      {:ok,
       %{
         "claim" => public_claim(next),
         "takeover" => %{
           "prior_writer_epoch" => claim.writer_epoch,
           "new_writer_epoch" => next.writer_epoch,
           "proof" => "issuer_quiescent"
         }
       }}
    else
      {:error, reason}
      when reason in [
             :not_found,
             :control_not_active,
             :ledger_closed,
             :ledger_generation_superseded
           ] ->
        {:reject, reason, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :claim_takeover_not_permitted, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "settle_claim"} = operation) do
    keys = ~w(type claim_id receipt_id request_id outcome proof payload authenticated_actor)

    with :ok <- exact_keys(operation, keys),
         :ok <- identities(operation, ~w(claim_id receipt_id request_id outcome proof)),
         true <- operation["outcome"] in ~w(succeeded failed non_started unknown),
         true <- operation["proof"] in ~w(delivered issuer_quiescent outcome_unknown),
         true <- plain_value?(operation["payload"]),
         {:ok, claim} <- load_claim(conn, operation["claim_id"]),
         {:ok, effect} <- load_effect(conn, claim.effect_id),
         :ok <- settlement_provenance(operation, claim, effect),
         {:ok, digest} <- receipt_digest(operation),
         {:ok, prior_receipts} <- receipts_for_claim(conn, claim.claim_id),
         {:ok, request_receipts} <- receipts_for_request(conn, operation["request_id"]),
         {:ok, observation_receipts} <- receipts_for_id(conn, operation["receipt_id"]) do
      cond do
        # A claim that was never issued has no observation to conflict with; quarantining
        # it commits a state the restart check refuses (ledger finding 1).
        claim.status in ["claimed", "cancelled"] ->
          {:reject, :claim_settlement_not_permitted, %{}}

        observation_conflict?(observation_receipts, operation, digest, claim) ->
          quarantine_conflicting_receipt(conn, operation, digest, claim, effect)

        Enum.any?(request_receipts, &(&1.claim_id != claim.claim_id)) ->
          quarantine_conflicting_receipt(conn, operation, digest, claim, effect)

        true ->
          settle_with_receipts(conn, operation, digest, claim, effect, prior_receipts)
      end
    else
      {:error, :not_found} ->
        {:reject, :claim_not_found, %{}}

      {:error, :receipt_provenance_mismatch} ->
        {:reject, :receipt_provenance_mismatch, %{}}

      {:error, _reason} = error ->
        error

      _ ->
        {:reject, :invalid_claim_settlement, %{}}
    end
  end

  def apply_operation(conn, %{"type" => "cancel_effect"} = operation) do
    with :ok <- exact_keys(operation, ~w(type effect_id proof)),
         true <- operation["proof"] in ~w(unissued issuer_quiescent control_ack),
         {:ok, effect} <- load_effect(conn, operation["effect_id"]) do
      cancel_effect(conn, effect, operation["proof"])
    else
      {:error, :not_found} -> {:reject, :effect_not_found, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :invalid_cancellation, %{}}
    end
  end

  # FR-08B protected items, item 1: the terminal_settlement_v1 producer. Closes a
  # (ticket, attempt) only when every effect under it is settled and every reservation it
  # activated is consumed, released or retired. The row makes the closure terminal:
  # create_effect refuses work under a closed attempt. Keyed on scope and attempt, never
  # on a role. A later conflicting receipt may still quarantine a closed attempt's effect
  # (R5); that moves no units, so the fact stays true as a statement about the ledger.
  def apply_operation(conn, %{"type" => "close_attempt"} = operation) do
    with :ok <- exact_keys(operation, ~w(type scope ticket_id attempt_id)),
         :ok <- identities(operation, ~w(scope ticket_id attempt_id)),
         true <- operation["scope"] == "ticket:" <> operation["ticket_id"],
         :ok <- attempt_open(conn, operation["ticket_id"], operation["attempt_id"]),
         {:ok, effects} <-
           attempt_effects(
             conn,
             operation["scope"],
             operation["ticket_id"],
             operation["attempt_id"]
           ),
         true <- Enum.all?(effects, &(&1.status in @closed_effect_statuses)),
         {:ok, reservations} <- attempt_reservations(conn, effects),
         true <- Enum.all?(reservations, &(&1.status in @closed_reservation_statuses)),
         fact <- attempt_settlement(operation, effects, reservations),
         {:ok, bytes} <- encode(fact),
         :ok <-
           Database.execute(
             conn,
             "INSERT INTO root_attempt_closures(ticket_id, attempt_id, scope, state) VALUES (?, ?, ?, ?)",
             [operation["ticket_id"], operation["attempt_id"], operation["scope"], {:blob, bytes}]
           ) do
      {:ok, %{"attempt_settlement" => fact}}
    else
      {:error, :attempt_closed} -> {:reject, :attempt_closed, %{}}
      {:error, _reason} = error -> error
      false -> {:reject, :attempt_not_settled, %{}}
      _ -> {:reject, :invalid_attempt_closure, %{}}
    end
  end

  def apply_operation(_conn, _operation), do: {:reject, :unsupported_operation, %{}}

  defp observation_conflict?([], _operation, _digest, _claim), do: false

  defp observation_conflict?(receipts, operation, digest, claim) do
    not Enum.all?(receipts, fn receipt ->
      receipt.receipt_id == operation["receipt_id"] and receipt.claim_id == claim.claim_id and
        receipt.request_id == operation["request_id"] and
        receipt.outcome == operation["outcome"] and receipt.receipt_digest == digest
    end)
  end

  defp close_subtree(conn, ledgers) do
    with :ok <-
           Enum.reduce_while(ledgers, :ok, fn ledger, :ok ->
             case if(ledger.status == "open",
                    do: revoke_unissued_generation(conn, ledger),
                    else: :ok
                  ) do
               :ok -> {:cont, :ok}
               error -> {:halt, error}
             end
           end) do
      Enum.reduce_while(ledgers, :ok, fn ledger, :ok ->
        with {:ok, current} <- load_existing_ledger(conn, ledger.ledger_id, ledger.generation),
             true <- current.status in ["open", "closed"],
             next <- %{
               current
               | revision: current.revision + 1,
                 status: "closed",
                 retired: current.retired + current.available,
                 available: 0
             },
             :ok <-
               if(current.status == "closed", do: :ok, else: update_ledger(conn, current, next)) do
          {:cont, :ok}
        else
          {:error, _reason} = error -> {:halt, error}
          _ -> {:halt, {:error, :generation_already_closed}}
        end
      end)
    end
  end

  defp revoke_unissued_generation(conn, ledger) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations WHERE ledger_id = ? AND generation = ? AND status = 'reserved' ORDER BY reservation_id",
             [ledger.ledger_id, ledger.generation]
           ),
         reservations <- Enum.map(rows, &reservation_from_row/1),
         :ok <- release_many(conn, reservations),
         :ok <- cancel_unissued_effect_owners(conn, reservations) do
      :ok
    end
  end

  defp cancel_unissued_effect_owners(conn, reservations) do
    reservations
    |> Enum.filter(&(&1.owner_kind == "effect"))
    |> Enum.map(& &1.owner_id)
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn effect_id, :ok ->
      case load_effect(conn, effect_id) do
        {:ok, %{status: "pending"} = effect} ->
          next = %{effect | status: "cancelled", revision: effect.revision + 1}

          case update_effect(conn, effect, next) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end

        {:ok, %{status: "claimed"} = effect} ->
          with {:ok, [[claim_id]]} <-
                 Database.query(conn, "SELECT claim_id FROM root_claims WHERE effect_id = ?", [
                   effect_id
                 ]),
               {:ok, claim} <- load_claim(conn, claim_id),
               next_claim <- %{claim | status: "cancelled", revision: claim.revision + 1},
               next_effect <- %{effect | status: "cancelled", revision: effect.revision + 1},
               :ok <- update_claim(conn, claim, next_claim),
               :ok <- update_effect(conn, effect, next_effect),
               :ok <- settle_leases(conn, claim_id, "cancelled") do
            {:cont, :ok}
          else
            {:error, _reason} = error -> {:halt, error}
          end

        {:ok, _effect} ->
          {:cont, :ok}

        {:error, :not_found} ->
          {:cont, :ok}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  defp cancel_effect(conn, %{status: "issued"} = effect, "control_ack") do
    with {:ok, [[claim_id]]} <-
           Database.query(
             conn,
             "SELECT claim_id FROM root_claims WHERE effect_id = ? AND status = 'issued'",
             [effect.effect_id]
           ) do
      {:ok,
       %{
         "effect" => public_effect(effect),
         "control_status" => "revocation_pending",
         "outstanding_claim_ids" => [claim_id]
       }}
    end
  end

  defp cancel_effect(conn, %{status: "pending"} = effect, "unissued") do
    with {:ok, reservations} <- reservations_for_effect(conn, effect.effect_id),
         :ok <- release_many(conn, reservations),
         next <- %{effect | status: "cancelled", revision: effect.revision + 1},
         :ok <- update_effect(conn, effect, next),
         {:ok, ledgers} <- ledger_facts_for_reservations(conn, reservations) do
      # The released hold moves each ledger; without its snapshot the restart check
      # refuses the ledger ({:protected_corrupt, "root_ledgers", :transition}).
      {:ok,
       %{"effect" => public_effect(next), "ledgers" => ledgers, "outstanding_claim_ids" => []}}
    end
  end

  defp cancel_effect(conn, %{status: "claimed"} = effect, "issuer_quiescent") do
    with {:ok, [[claim_id]]} <-
           Database.query(
             conn,
             "SELECT claim_id FROM root_claims WHERE effect_id = ? AND status = 'claimed'",
             [effect.effect_id]
           ),
         {:ok, claim} <- load_claim(conn, claim_id),
         {:ok, reservations} <- reservations_for_claim(conn, claim_id),
         :ok <- release_many(conn, reservations),
         next_claim <- %{claim | status: "cancelled", revision: claim.revision + 1},
         next_effect <- %{effect | status: "cancelled", revision: effect.revision + 1},
         :ok <- update_claim(conn, claim, next_claim),
         :ok <- update_effect(conn, effect, next_effect),
         :ok <- settle_leases(conn, claim_id, "cancelled"),
         {:ok, ledgers} <- ledger_facts_for_reservations(conn, reservations) do
      {:ok,
       %{
         "effect" => public_effect(next_effect),
         "claim" => public_claim(next_claim),
         "ledgers" => ledgers,
         "outstanding_claim_ids" => []
       }}
    end
  end

  defp cancel_effect(_conn, _effect, _proof), do: {:reject, :cancellation_not_permitted, %{}}

  defp fence_control_descendants(_conn, _control_id, %{"status" => "active"}),
    do: {:ok, {[], []}}

  # Returns the outstanding claims and the snapshots of every ledger a cascaded cancel
  # released a hold on; the restart check needs those snapshots exactly as it does for a
  # direct cancel_effect (Fable review of d67eeac2). A ledger two cancels touched keeps
  # its last snapshot, which is its current state.
  defp fence_control_descendants(conn, control_id, %{"status" => "cancel_requested"}) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT effect_id FROM root_effects WHERE control_id = ? AND status IN ('pending', 'claimed', 'issued', 'unknown', 'reconciliation_required') ORDER BY effect_id",
             [control_id]
           ) do
      rows
      |> Enum.reduce_while({:ok, {[], []}}, fn [effect_id], {:ok, {outstanding, ledgers}} ->
        with {:ok, effect} <- load_effect(conn, effect_id) do
          case effect.status do
            "pending" ->
              case cancel_effect(conn, effect, "unissued") do
                {:ok, facts} -> {:cont, {:ok, {outstanding, ledgers ++ facts["ledgers"]}}}
                error -> {:halt, error}
              end

            "claimed" ->
              case cancel_effect(conn, effect, "issuer_quiescent") do
                {:ok, facts} -> {:cont, {:ok, {outstanding, ledgers ++ facts["ledgers"]}}}
                error -> {:halt, error}
              end

            status when status in ["issued", "unknown", "reconciliation_required"] ->
              case Database.query(
                     conn,
                     "SELECT claim_id FROM root_claims WHERE effect_id = ? ORDER BY claim_id",
                     [effect_id]
                   ) do
                {:ok, claims} ->
                  {:cont, {:ok, {outstanding ++ Enum.map(claims, &hd/1), ledgers}}}

                error ->
                  {:halt, error}
              end
          end
        else
          error -> {:halt, error}
        end
      end)
      |> then(fn
        {:ok, {outstanding, ledgers}} ->
          latest =
            ledgers
            |> Enum.reverse()
            |> Enum.uniq_by(&{&1["ledger_id"], &1["generation"]})
            |> Enum.reverse()

          {:ok, {outstanding, latest}}

        error ->
          error
      end)
    end
  end

  defp fence_control_descendants(_conn, _control_id, _value),
    do: {:error, :invalid_control_state}

  # A cancel releases its effect's holds. A hold an accepted release_reservation already
  # returned is skipped: nothing was issued, so the cancel's premise holds, and releasing it
  # again would count its units twice. Any other status is a refusal, not a storage error:
  # an error here flipped the live Gateway into recovery (live_refusal_probe_test.exs, L1).
  # replay_release_reservations skips the same holds.
  defp release_many(conn, reservations) do
    Enum.reduce_while(reservations, :ok, fn
      %{status: status}, :ok when status in ["released", "retired"] ->
        {:cont, :ok}

      reservation, :ok ->
        with true <- reservation.status == "reserved",
             {:ok, ledger} <-
               load_existing_ledger(conn, reservation.ledger_id, reservation.generation),
             next_reservation <- %{
               reservation
               | status: if(ledger.status == "open", do: "released", else: "retired"),
                 revision: reservation.revision + 1
             },
             next_ledger <- release_hold(ledger, reservation.units),
             :ok <- update_reservation(conn, reservation, next_reservation),
             :ok <- update_ledger(conn, ledger, next_ledger) do
          {:cont, :ok}
        else
          {:error, _reason} = error -> {:halt, error}
          _ -> {:halt, {:reject, :reservation_release_not_permitted, %{}}}
        end
    end)
  end

  defp settle_with_receipts(conn, operation, digest, claim, effect, receipts) do
    exact =
      Enum.find(receipts, fn receipt ->
        receipt.receipt_id == operation["receipt_id"] and
          receipt.request_id == operation["request_id"] and
          receipt.outcome == operation["outcome"] and receipt.receipt_digest == digest
      end)

    cond do
      exact ->
        {:ok,
         %{
           "claim" => public_claim(claim),
           "effect" => public_effect(effect),
           "receipt" => public_receipt(exact)
         }}

      # A quarantined claim is not reconciled by an ordinary receipt. Quarantine does not
      # store the conflicting receipt, so the earlier unknown-only history below would read a
      # later known outcome as a reconciliation and settle it with no recovery record
      # (FR-10 Q3 probe, quarantine_exit_probe_test.exs). Leaving quarantine needs an explicit
      # recovery operation, which FR-10 owns; until then it fails closed.
      claim.status == "reconciliation_required" ->
        quarantine_conflicting_receipt(conn, operation, digest, claim, effect)

      # The same observation under another receipt_id. root_receipts is unique on
      # (claim_id, receipt_digest) and the digest omits receipt_id, so storing it failed as a
      # storage error once FR-10 finding B began storing late unknown receipts
      # (live_refusal_probe_test.exs, L3).
      Enum.any?(receipts, &(&1.receipt_digest == digest)) ->
        {:reject, :duplicate_receipt_observation, %{}}

      # An unknown receipt carries less information than any stored receipt, never
      # conflicting information: store it and leave the status alone (FR-10 finding B). A
      # late timeout must not re-quarantine an effect already settled from its outcome.
      receipts != [] and operation["outcome"] == "unknown" ->
        stale_unknown_receipt(conn, operation, digest, claim, effect)

      receipts != [] ->
        if Enum.all?(receipts, &(&1.outcome == "unknown")) do
          reconciled_settlement(conn, operation, digest, claim, effect)
        else
          quarantine_conflicting_receipt(conn, operation, digest, claim, effect)
        end

      true ->
        first_settlement(conn, operation, digest, claim, effect)
    end
  end

  defp stale_unknown_receipt(conn, operation, digest, claim, effect) do
    receipt = receipt(operation, digest, claim.claim_id)

    with :ok <- settlement_proof("unknown", operation["proof"]),
         :ok <- insert_receipt(conn, receipt) do
      {:ok,
       %{
         "claim" => public_claim(claim),
         "effect" => public_effect(effect),
         "receipt" => public_receipt(receipt)
       }}
    else
      {:error, :invalid_receipt_proof} -> {:reject, :invalid_receipt_proof, %{}}
      {:error, _reason} = error -> error
    end
  end

  defp settlement_provenance(operation, claim, effect) do
    with true <- operation["request_id"] == effect.request_id,
         true <- operation["authenticated_actor"] == effect.issuer,
         true <- effect.channel == "protected-gateway",
         true <-
           operation["proof"] != "issuer_quiescent" or
             operation["payload"]["quiescence_epoch"] == claim.writer_epoch do
      :ok
    else
      _ -> {:error, :receipt_provenance_mismatch}
    end
  end

  defp reconciled_settlement(conn, operation, digest, claim, effect) do
    receipt = receipt(operation, digest, claim.claim_id)

    with :ok <- settlement_proof(operation["outcome"], operation["proof"]),
         {:ok, reservations} <- reservations_for_claim(conn, claim.claim_id),
         :ok <- insert_receipt(conn, receipt),
         :ok <- settle_reservations(conn, reservations, operation["outcome"]),
         next_claim <- %{
           claim
           | status: operation["outcome"],
             revision: claim.revision + 1
         },
         next_effect <- %{
           effect
           | status: operation["outcome"],
             revision: effect.revision + 1
         },
         :ok <- update_claim(conn, claim, next_claim),
         :ok <- update_effect(conn, effect, next_effect),
         :ok <- settle_leases(conn, claim.claim_id, operation["outcome"]),
         {:ok, ledgers} <- ledger_facts_for_reservations(conn, reservations) do
      {:ok,
       %{
         "claim" => public_claim(next_claim),
         "effect" => public_effect(next_effect),
         "receipt" => public_receipt(receipt),
         "ledgers" => ledgers
       }}
    else
      {:error, reason} when reason in [:invalid_receipt_proof] -> {:reject, reason, %{}}
      {:error, _reason} = error -> error
    end
  end

  defp first_settlement(conn, operation, digest, claim, effect) do
    outcome = operation["outcome"]

    with true <- claim.status in ["issued", "unknown"],
         :ok <- settlement_proof(outcome, operation["proof"]),
         {:ok, reservations} <- reservations_for_claim(conn, claim.claim_id),
         true <- reservations != [],
         receipt <- receipt(operation, digest, claim.claim_id),
         :ok <- insert_receipt(conn, receipt),
         :ok <- settle_reservations(conn, reservations, outcome),
         next_status <- if(outcome == "unknown", do: "unknown", else: outcome),
         next_claim <- %{claim | status: next_status, revision: claim.revision + 1},
         next_effect <- %{effect | status: next_status, revision: effect.revision + 1},
         :ok <- update_claim(conn, claim, next_claim),
         :ok <- update_effect(conn, effect, next_effect),
         :ok <- settle_leases(conn, claim.claim_id, outcome),
         {:ok, ledger_facts} <- ledger_facts_for_reservations(conn, reservations) do
      {:ok,
       %{
         "claim" => public_claim(next_claim),
         "effect" => public_effect(next_effect),
         "receipt" => public_receipt(receipt),
         "ledgers" => ledger_facts
       }}
    else
      {:error, reason} when reason in [:invalid_receipt_proof] -> {:reject, reason, %{}}
      {:error, _reason} = error -> error
      _ -> {:reject, :claim_settlement_not_permitted, %{}}
    end
  end

  defp quarantine_conflicting_receipt(conn, operation, digest, claim, effect) do
    attempted = receipt(operation, digest, claim.claim_id)
    next_claim = %{claim | status: "reconciliation_required", revision: claim.revision + 1}
    next_effect = %{effect | status: "reconciliation_required", revision: effect.revision + 1}

    with :ok <- update_claim(conn, claim, next_claim),
         :ok <- update_effect(conn, effect, next_effect),
         :ok <- retain_leases(conn, claim.claim_id) do
      {:quarantine, :conflicting_receipt,
       %{
         "claim" => public_claim(next_claim),
         "effect" => public_effect(next_effect),
         "attempted_receipt" => public_receipt(attempted)
       }}
    end
  end

  defp upsert_simple_root(conn, table, id_column, id, operation) do
    with :ok <- exact_keys(operation, ["type", id_column, "value", "root_command_id"]),
         :ok <- identity(id),
         true <- plain_map?(operation["value"]),
         {:ok, current} <- load_simple_optional(conn, table, id_column, id),
         revision <- if(current == :absent, do: 0, else: current.revision + 1),
         state <- %{
           "schema_version" => 1,
           id_column => id,
           "revision" => revision,
           "value" => operation["value"]
         },
         {:ok, bytes} <- encode(state),
         :ok <-
           insert_simple_history(
             conn,
             table,
             id_column,
             id,
             revision,
             operation["root_command_id"],
             bytes
           ),
         :ok <- write_simple(conn, table, id_column, id, revision, bytes, current) do
      {:ok, %{String.trim_trailing(table, "s") => state}}
    else
      {:error, _reason} = error -> error
      _ -> {:reject, :invalid_root_revision, %{}}
    end
  end

  defp release_hold(ledger, units) do
    if ledger.status == "open" do
      %{
        ledger
        | revision: ledger.revision + 1,
          held: ledger.held - units,
          available: ledger.available + units
      }
    else
      %{
        ledger
        | revision: ledger.revision + 1,
          held: ledger.held - units,
          retired: ledger.retired + units
      }
    end
  end

  defp activate_reservations(conn, reservations) do
    Enum.reduce_while(reservations, {:ok, []}, fn reservation, {:ok, acc} ->
      with "proposed" <- reservation.status,
           {:ok, ledger} <-
             load_existing_ledger(conn, reservation.ledger_id, reservation.generation),
           "open" <- ledger.status,
           true <- reservation.units <= ledger.available,
           next_ledger <- %{
             ledger
             | revision: ledger.revision + 1,
               available: ledger.available - reservation.units,
               held: ledger.held + reservation.units
           },
           next_reservation <- %{
             reservation
             | revision: reservation.revision + 1,
               status: "reserved"
           },
           :ok <- update_ledger(conn, ledger, next_ledger),
           :ok <- update_reservation(conn, reservation, next_reservation) do
        {:cont, {:ok, [next_reservation | acc]}}
      else
        {:error, _reason} = error -> {:halt, error}
        _ -> {:halt, {:error, :reservation_activation_not_permitted}}
      end
    end)
    |> then(fn
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end)
  end

  defp maybe_update_ledger(_conn, ledger, ledger), do: :ok
  defp maybe_update_ledger(conn, old, next), do: update_ledger(conn, old, next)

  defp attempt_settlement(operation, effects, reservations) do
    units =
      Enum.reduce(reservations, %{}, fn reservation, acc ->
        update_in(
          acc,
          [Access.key(reservation.status, %{}), Access.key(reservation.dimension, 0)],
          &(&1 + reservation.units)
        )
      end)

    %{
      "schema_version" => 1,
      "scope" => operation["scope"],
      "ticket_id" => operation["ticket_id"],
      "attempt_id" => operation["attempt_id"],
      "effect_ids" => Enum.map(effects, & &1.effect_id),
      "settled_units" => units
    }
  end

  # Lease requests are held in the effect's protected state until claim identity exists.
  defp insert_pending_leases(conn, effect_id, specs) do
    with {:ok, effect} <- load_effect(conn, effect_id),
         next <- Map.put(effect, :lease_specs, specs) do
      update_effect(conn, effect, next)
    end
  end

  defp bind_reservations_to_claim(conn, reservations, claim_id) do
    Enum.reduce_while(reservations, :ok, fn reservation, :ok ->
      next = %{reservation | claim_id: claim_id, revision: reservation.revision + 1}

      case update_reservation(conn, reservation, next) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp update_reservation_statuses(conn, reservations, status) do
    Enum.reduce_while(reservations, :ok, fn reservation, :ok ->
      next = %{reservation | status: status, revision: reservation.revision + 1}

      case update_reservation(conn, reservation, next) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp materialize_leases(conn, effect_id, claim_id) do
    with {:ok, effect} <- load_effect(conn, effect_id) do
      Enum.reduce_while(effect.lease_specs, :ok, fn spec, :ok ->
        lease = %{
          lease_id: spec["lease_id"],
          claim_id: claim_id,
          resource_id: spec["resource_id"],
          status: "held",
          revision: 0
        }

        with {:ok, bytes} <- encode(public_lease(lease)),
             :ok <-
               Database.execute(
                 conn,
                 "INSERT INTO root_leases(lease_id, claim_id, resource_id, status, revision, state) VALUES (?, ?, ?, 'held', 0, ?)",
                 [lease.lease_id, claim_id, lease.resource_id, {:blob, bytes}]
               ) do
          {:cont, :ok}
        else
          {:error, _reason} = error -> {:halt, error}
        end
      end)
    end
  end

  defp settle_reservations(_conn, _reservations, "unknown"), do: :ok

  defp settle_reservations(conn, reservations, outcome) do
    Enum.reduce_while(reservations, :ok, fn reservation, :ok ->
      with {:ok, ledger} <-
             load_existing_ledger(conn, reservation.ledger_id, reservation.generation),
           true <- reservation.status == "issued_unknown",
           {reservation_status, next_ledger} <-
             reservation_settlement(ledger, reservation, outcome),
           next_reservation <- %{
             reservation
             | status: reservation_status,
               revision: reservation.revision + 1
           },
           :ok <- update_reservation(conn, reservation, next_reservation),
           :ok <- update_ledger(conn, ledger, next_ledger) do
        {:cont, :ok}
      else
        {:error, _reason} = error -> {:halt, error}
        _ -> {:halt, {:error, :reservation_settlement_conflict}}
      end
    end)
  end

  defp reservation_settlement(ledger, reservation, outcome)
       when outcome in ~w(succeeded failed) do
    {"consumed",
     %{
       ledger
       | revision: ledger.revision + 1,
         held: ledger.held - reservation.units,
         consumed: ledger.consumed + reservation.units
     }}
  end

  defp reservation_settlement(ledger, reservation, "non_started") do
    target = if ledger.status == "open", do: "released", else: "retired"
    {target, release_hold(ledger, reservation.units)}
  end

  defp settle_leases(_conn, _claim_id, "unknown"), do: :ok
  defp settle_leases(conn, claim_id, _outcome), do: update_leases(conn, claim_id, "released")

  defp retain_leases(conn, claim_id),
    do: update_leases(conn, claim_id, "retained", ["held", "retained"])

  defp update_leases(
         conn,
         claim_id,
         status,
         from_statuses \\ ["held", "retained", "released"]
       ) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT lease_id, claim_id, resource_id, status, revision FROM root_leases WHERE claim_id = ? ORDER BY lease_id",
             [claim_id]
           ) do
      Enum.reduce_while(rows, :ok, fn [id, claim, resource, old_status, revision], :ok ->
        if old_status not in from_statuses do
          {:cont, :ok}
        else
          next = %{
            lease_id: id,
            claim_id: claim,
            resource_id: resource,
            status: status,
            revision: revision + 1
          }

          with {:ok, bytes} <- encode(public_lease(next)),
               :ok <-
                 Database.execute(
                   conn,
                   "UPDATE root_leases SET status = ?, revision = ?, state = ? WHERE lease_id = ? AND revision = ?",
                   [status, revision + 1, {:blob, bytes}, id, revision]
                 ) do
            {:cont, :ok}
          else
            {:error, _reason} = error -> {:halt, error}
          end
        end
      end)
    end
  end
end
