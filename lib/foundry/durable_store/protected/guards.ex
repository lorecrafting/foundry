defmodule Foundry.DurableStore.Protected.Guards do
  @moduledoc false

  alias Foundry.DurableStore.Database

  import Foundry.DurableStore.Protected.Rows

  @dimensions ~w(starts.pm starts.developer starts.reviewer starts.check starts.build operations.integration operations.activation model_requests validations)

  def dimensions, do: @dimensions

  @doc """
  Re-derives the discriminator for a past settlement from retained policy history.

  Both the commit path and revalidation use this function. Reading the current policy head
  instead failed closed once policy was revised, which stranded a proved non-start at commit
  time (contract reading Q5: it must still settle) and would report a valid historical
  commit as corrupt on revalidation. `root_policy_history` retains every revision under `PRIMARY KEY(policy_id,
  revision)` with a chain constraint, and its lineage is validated on open, so the limit
  in force at the effect's recorded `policy_revision` is recoverable and integrity-checked.

  Fails closed when the history row is absent, the limit is missing or non-positive, or
  the settlement disagrees with the effect.
  """
  @spec infrastructure_discriminator_at_revision(term(), String.t(), map()) ::
          {:ok, String.t()} | {:error, atom()}
  def infrastructure_discriminator_at_revision(conn, effect_id, settlement)
      when is_map(settlement) do
    with {:ok, effect} <- load_effect(conn, effect_id),
         true <- effect.role == settlement["role"],
         {:ok, [[bytes]]} <-
           Database.query(
             conn,
             "SELECT state FROM root_policy_history WHERE policy_id = ? AND revision = ?",
             [effect.policy_id, effect.policy_revision]
           ),
         {:ok, state} <- decode(bytes),
         limits when is_map(limits) <- get_in(state, ["value", "infrastructure_attempt_limits"]),
         limit when is_integer(limit) and limit > 0 <- Map.get(limits, effect.role),
         ordinal when is_integer(ordinal) and ordinal > 0 <- settlement["ordinal"] do
      if ordinal < limit,
        do: {:ok, "below_infrastructure_limit"},
        else: {:ok, "infrastructure_limit_reached"}
    else
      _ -> {:error, :infrastructure_limit_undecidable}
    end
  end

  def infrastructure_discriminator_at_revision(_conn, _effect_id, _settlement),
    do: {:error, :infrastructure_limit_undecidable}

  def inbox_append_guard(:absent, 1), do: {:ok, "accepted"}
  def inbox_append_guard(:absent, _sequence), do: {:error, :inbox_sequence_conflict}

  def inbox_append_guard(%{last_sequence: last, sealed_sequence: sealed}, sequence)
      when sequence == last + 1 and not is_nil(sealed),
      do: {:ok, "late"}

  def inbox_append_guard(%{last_sequence: last}, sequence) when sequence == last + 1,
    do: {:ok, "accepted"}

  def inbox_append_guard(_inbox, _sequence), do: {:error, :inbox_sequence_conflict}
  def release_guard(_conn, %{claim_id: nil}), do: :ok

  def release_guard(conn, %{claim_id: claim_id}) do
    with {:ok, claim} <- load_claim(conn, claim_id) do
      if claim.status == "claimed", do: :ok, else: {:error, :claim_already_issued}
    end
  end

  def reservations_open?(conn, reservations) do
    Enum.reduce_while(reservations, :ok, fn reservation, :ok ->
      case load_existing_ledger(conn, reservation.ledger_id, reservation.generation) do
        {:ok, %{status: "open"}} ->
          case current_generation(conn, reservation.ledger_id) do
            {:ok, generation} when generation == reservation.generation -> {:cont, :ok}
            {:ok, _newer} -> {:halt, {:error, :ledger_generation_superseded}}
            {:error, _reason} = error -> {:halt, error}
          end

        {:ok, %{status: "closed"}} ->
          {:halt, {:error, :ledger_closed}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  def allowed_effect?(policy, control, operation) do
    with :ok <- control_active?(control),
         operations when is_list(operations) <- policy["allowed_operations"],
         scopes when is_list(scopes) <- policy["allowed_scopes"],
         roles when is_list(roles) <- policy["allowed_roles"] || [operation["request"]["role"]],
         profiles when is_list(profiles) <-
           policy["allowed_profiles"] || [operation["request"]["profile"] || "unspecified"],
         true <- operation["operation"] in operations,
         true <- operation["scope"] in scopes,
         true <- operation["scope"] == "ticket:" <> operation["ticket_id"],
         true <- operation["request"]["role"] in roles,
         true <- Map.get(operation["request"], "profile", "unspecified") in profiles,
         true <- deadline_allowed?(policy, operation["request"]["deadline"]) do
      :ok
    else
      {:error, _reason} = error -> error
      _ -> {:error, :effect_not_allowed}
    end
  end

  defp deadline_allowed?(policy, deadline) do
    case Map.fetch(policy, "allowed_deadlines") do
      :error -> is_nil(deadline)
      {:ok, deadlines} -> is_list(deadlines) and is_integer(deadline) and deadline in deadlines
    end
  end

  # One per-role limit, the same one the infrastructure discriminator reads. Reading the
  # policy-wide scalar `launch_non_start_limit` (default 0) here stranded every retry the
  # discriminator had just selected: the non-start settled below the limit, and the retry's
  # create_effect was refused (decide/3 design review, C2). The contract names the limit
  # `launch_non_start_limit` "per role and work owner"; the protected key that holds it per
  # role is `infrastructure_attempt_limits`.
  def nonstart_allowance(conn, policy, operation) do
    limit =
      case policy["infrastructure_attempt_limits"] do
        limits when is_map(limits) -> Map.get(limits, operation["request"]["role"], 0)
        _ -> 0
      end

    with true <- is_integer(limit) and limit >= 0,
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT state FROM root_effects WHERE ticket_id = ? AND attempt_id = ? AND operation = ? AND status = 'non_started'",
             [operation["ticket_id"], operation["attempt_id"], operation["operation"]]
           ),
         count <-
           Enum.count(rows, fn [bytes] ->
             case decode(bytes) do
               {:ok, state} -> state["role"] == operation["request"]["role"]
               _ -> true
             end
           end),
         true <- count < limit or rows == [] do
      :ok
    else
      _ -> {:error, :nonstart_allowance_exhausted}
    end
  end

  # Reviewer independence (REPAIR-PLAN.md#reviewer-independence-amendment). The operator
  # policy's `independent_of_roles` maps a role to the roles it must share no recorded
  # principal with inside one ticket attempt; role names are policy data, not Core's. A
  # side's principals are the issuer and inbox actor of every effect of its roles in the
  # attempt, so a retry inherits its whole predecessor chain. Checked in both directions
  # against every such effect: the controller names nothing and so can skip nothing.
  # Until FR-15aB these are recorded principals, not proved-isolated ones.
  #
  # The pairings are the union of the caller's policy and the revision each effect already
  # in the attempt pinned, read from root_policy_history as
  # infrastructure_discriminator_at_revision does. Once any effect of the attempt was
  # created under a pairing, it binds the rest of the attempt, whatever the policy says
  # later and whichever policy_id a later operation names.
  def principal_independence(conn, policy, ticket_id, attempt_id, role, principals) do
    with {:ok, pinned} <- pinned_policies(conn, ticket_id, attempt_id),
         {:ok, related} <- related_roles([policy | pinned], role),
         {:ok, effects} <- independence_effects(conn, ticket_id, attempt_id, related),
         {:ok, own} <- side_principals(conn, effects, [role]),
         {:ok, other} <- side_principals(conn, effects, related),
         true <- MapSet.disjoint?(MapSet.union(own, MapSet.new(principals)), other) do
      :ok
    else
      _ -> {:error, :principal_not_independent}
    end
  end

  defp pinned_policies(conn, ticket_id, attempt_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT DISTINCT policy_id, policy_revision FROM root_effects WHERE ticket_id = ? AND attempt_id = ?",
             [ticket_id, attempt_id]
           ) do
      Enum.reduce_while(rows, {:ok, []}, fn [policy_id, revision], {:ok, acc} ->
        with {:ok, [[bytes]]} <-
               Database.query(
                 conn,
                 "SELECT state FROM root_policy_history WHERE policy_id = ? AND revision = ?",
                 [policy_id, revision]
               ),
             {:ok, %{"value" => value}} when is_map(value) <- decode(bytes) do
          {:cont, {:ok, [value | acc]}}
        else
          _ -> {:halt, :error}
        end
      end)
    end
  end

  defp related_roles(policies, role) do
    Enum.reduce_while(policies, {:ok, []}, fn policy, {:ok, acc} ->
      with pairs when is_map(pairs) <- Map.get(policy, "independent_of_roles", %{}),
           true <-
             Enum.all?(pairs, fn {from, to} ->
               is_binary(from) and is_list(to) and Enum.all?(to, &is_binary/1)
             end) do
        related = Map.get(pairs, role, []) ++ for({from, to} <- pairs, role in to, do: from)
        {:cont, {:ok, Enum.uniq(acc ++ related)}}
      else
        _ -> {:halt, :error}
      end
    end)
  end

  defp independence_effects(_conn, _ticket_id, _attempt_id, []), do: {:ok, []}

  defp independence_effects(conn, ticket_id, attempt_id, _related) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT state FROM root_effects WHERE ticket_id = ? AND attempt_id = ? ORDER BY effect_id",
             [ticket_id, attempt_id]
           ) do
      Enum.reduce_while(rows, {:ok, []}, fn [bytes], {:ok, acc} ->
        case decode(bytes) do
          {:ok, state} -> {:cont, {:ok, [state | acc]}}
          _ -> {:halt, :error}
        end
      end)
    end
  end

  defp side_principals(conn, effects, roles) do
    effects
    |> Enum.filter(&(&1["role"] in roles))
    |> Enum.reduce_while({:ok, MapSet.new()}, fn effect, {:ok, acc} ->
      case load_inbox(conn, effect["execution_id"]) do
        {:ok, inbox} ->
          {:cont,
           {:ok, MapSet.new([effect["issuer"] | inbox_principals(inbox)]) |> MapSet.union(acc)}}

        error ->
          {:halt, error}
      end
    end)
  end

  def inbox_principals(%{actor_id: actor}), do: [actor]
  def inbox_principals(:absent), do: []

  # The first append pins the execution's inbox actor; later appends must match it.
  def inbox_independence(conn, :absent, operation) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT policy_id, ticket_id, attempt_id, state FROM root_effects WHERE execution_id = ? ORDER BY effect_id",
             [operation["execution_id"]]
           ) do
      Enum.reduce_while(rows, :ok, fn [policy_id, ticket_id, attempt_id, bytes], :ok ->
        with {:ok, effect} <- decode(bytes),
             {:ok, policy} <- load_simple(conn, "root_policies", "policy_id", policy_id),
             :ok <-
               principal_independence(
                 conn,
                 policy.value,
                 ticket_id,
                 attempt_id,
                 effect["role"],
                 [operation["authenticated_actor"]]
               ) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, :principal_not_independent}}
        end
      end)
    end
  end

  def inbox_independence(_conn, _inbox, _operation), do: :ok

  def control_active?(%{"status" => "active"}), do: :ok
  def control_active?(_control), do: {:error, :control_not_active}

  def load_effect_reservations(conn, operation) do
    effect_id = operation["effect_id"]

    operation["reservation_ids"]
    |> Enum.reduce_while({:ok, []}, fn id, {:ok, acc} ->
      case load_reservation(conn, id) do
        {:ok, reservation}
        when reservation.owner_kind == "effect" and
               reservation.owner_id == effect_id and
               reservation.status == "proposed" and is_nil(reservation.claim_id) ->
          {:cont, {:ok, [reservation | acc]}}

        {:ok, %{status: status}} when status != "proposed" ->
          {:halt, {:error, :reservation_not_held}}

        {:ok, _reservation} ->
          {:halt, {:error, :reservation_owner_mismatch}}

        {:error, :not_found} ->
          {:halt, {:error, :reservation_not_found}}

        error ->
          {:halt, error}
      end
    end)
    |> then(fn
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end)
  end

  # The restart check allows a proposed reservation only while its owner effect does not
  # exist, and create_effect is the only activation (spec/ledger finding 3).
  def owner_not_created(conn, owner_id) do
    case Database.query(conn, "SELECT effect_id FROM root_effects WHERE effect_id = ?", [
           owner_id
         ]) do
      {:ok, []} -> :ok
      {:ok, _rows} -> {:error, :reservation_owner_exists}
      error -> error
    end
  end

  # Same check, from the effect's side: the restart check requires an effect to list every
  # reservation it owns, in any status. Only proposed ones can be activated, so an owner with
  # an earlier released reservation can never be created (reopen property F2).
  def all_owned_listed(conn, effect_id, reservations) do
    listed = MapSet.new(reservations, & &1.reservation_id)

    case Database.query(
           conn,
           "SELECT reservation_id FROM root_reservations WHERE owner_id = ?",
           [effect_id]
         ) do
      {:ok, rows} ->
        if Enum.all?(rows, fn [id] -> MapSet.member?(listed, id) end),
          do: :ok,
          else: {:error, :unlisted_owned_reservation}

      error ->
        error
    end
  end

  # A list naming one lease or resource twice passes the per-spec query below, then fails
  # root_leases' unique keys as a storage error when the claim materializes it
  # (live_refusal_probe_test.exs, L4). Checked here, not in normalize_lease_specs, so the
  # restart check still accepts an effect created before this guard.
  def lease_specs_available(conn, specs) do
    if Enum.uniq_by(specs, & &1["lease_id"]) == specs and
         Enum.uniq_by(specs, & &1["resource_id"]) == specs,
       do: leases_unheld(conn, specs),
       else: {:error, :lease_conflict}
  end

  defp leases_unheld(conn, specs) do
    Enum.reduce_while(specs, :ok, fn spec, :ok ->
      case Database.query(
             conn,
             "SELECT lease_id FROM root_leases WHERE lease_id = ? OR (resource_id = ? AND status IN ('held', 'retained'))",
             [spec["lease_id"], spec["resource_id"]]
           ) do
        {:ok, []} -> {:cont, :ok}
        {:ok, _rows} -> {:halt, {:error, :lease_conflict}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  def attempt_open(conn, ticket_id, attempt_id) do
    case Database.query(
           conn,
           "SELECT 1 FROM root_attempt_closures WHERE ticket_id = ? AND attempt_id = ?",
           [ticket_id, attempt_id]
         ) do
      {:ok, []} -> :ok
      {:ok, _} -> {:error, :attempt_closed}
      {:error, _reason} = error -> error
    end
  end

  def semantic_effect_available(conn, operation) do
    role = Map.get(operation["request"], "role")
    request_id = Map.get(operation["request"], "request_id")
    phase_generation = Map.get(operation["request"], "phase_generation", 0)
    ordinal = Map.get(operation["request"], "operation_ordinal", 0)

    with {:ok, request_rows} <- Database.query(conn, "SELECT state FROM root_effects"),
         false <-
           Enum.any?(request_rows, fn [bytes] ->
             case decode(bytes) do
               {:ok, state} -> state["request_id"] == request_id
               _ -> true
             end
           end),
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT state FROM root_effects WHERE ticket_id = ? AND attempt_id = ? AND operation = ? AND status IN ('pending', 'claimed', 'issued', 'unknown', 'reconciliation_required')",
             [operation["ticket_id"], operation["attempt_id"], operation["operation"]]
           ) do
      duplicate? =
        Enum.any?(rows, fn [bytes] ->
          case decode(bytes) do
            {:ok, state} ->
              state["role"] == role and state["phase_generation"] == phase_generation and
                state["operation_ordinal"] == ordinal

            _ ->
              true
          end
        end)

      if duplicate?, do: {:error, :duplicate_semantic_operation}, else: :ok
    else
      true -> {:error, :duplicate_request_identity}
      {:error, _reason} = error -> error
    end
  end

  def predecessor_guard(conn, operation, generation, ordinal, predecessor) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT effect_id, state FROM root_effects WHERE ticket_id = ? AND attempt_id = ? AND operation = ? ORDER BY effect_id",
             [operation["ticket_id"], operation["attempt_id"], operation["operation"]]
           ),
         lineage <-
           Enum.flat_map(rows, fn [id, bytes] ->
             case decode(bytes) do
               {:ok, state} ->
                 if state["role"] == operation["request"]["role"], do: [{id, state}], else: []

               _ ->
                 []
             end
           end) do
      case lineage do
        [] ->
          if generation == 0 and ordinal == 0 and is_nil(predecessor),
            do: :ok,
            else: {:error, :predecessor_identity_mismatch}

        values ->
          {latest_id, latest} =
            Enum.max_by(values, fn {_id, state} -> state["operation_ordinal"] end)

          if predecessor == latest_id and generation == latest["phase_generation"] and
               ordinal == latest["operation_ordinal"] + 1 and
               latest["status"] in ~w(succeeded failed non_started cancelled) do
            :ok
          else
            {:error, :predecessor_not_terminal}
          end
      end
    end
  end

  def predecessor_current?(conn, effect),
    do: predecessor_current?(conn, effect, MapSet.new([effect.effect_id]))

  defp predecessor_current?(
         _conn,
         %{operation_ordinal: 0, predecessor_effect_id: nil},
         _seen
       ),
       do: :ok

  defp predecessor_current?(conn, effect, seen) do
    with predecessor when is_binary(predecessor) <- effect.predecessor_effect_id,
         false <- MapSet.member?(seen, predecessor),
         {:ok, prior} <- load_effect(conn, predecessor),
         true <- prior.status in ~w(succeeded failed non_started cancelled),
         true <- prior.assignment_id == effect.assignment_id,
         true <- prior.phase_generation == effect.phase_generation,
         true <- prior.operation_ordinal + 1 == effect.operation_ordinal,
         :ok <- predecessor_current?(conn, prior, MapSet.put(seen, predecessor)) do
      :ok
    else
      _ -> {:error, :predecessor_not_terminal}
    end
  end

  def reservation_dimensions(operation, reservations) do
    role = operation["request"]["role"]

    with {:ok, required} <- required_dimension(operation["operation"], role),
         true <- Enum.all?(reservations, &(&1.dimension == required)) do
      single_ledger(reservations)
    else
      _ -> {:error, :operation_dimension_mismatch}
    end
  end

  # One ledger generation per effect: close_generation releases only its own ledger's
  # holds and cancels the owner, so a second ledger's hold would be stranded under a
  # cancelled effect, which the restart check rejects (spec/ledger finding 2).
  defp single_ledger(reservations) do
    case Enum.uniq_by(reservations, &{&1.ledger_id, &1.generation}) do
      [_, _ | _] -> {:error, :reservation_ledger_mismatch}
      _ -> :ok
    end
  end

  def required_dimension("launch", "pm"), do: {:ok, "starts.pm"}
  def required_dimension("launch", "developer"), do: {:ok, "starts.developer"}
  def required_dimension("launch", "reviewer"), do: {:ok, "starts.reviewer"}
  def required_dimension("check", _role), do: {:ok, "starts.check"}
  def required_dimension("build", _role), do: {:ok, "starts.build"}
  def required_dimension("integration", _role), do: {:ok, "operations.integration"}
  def required_dimension("activation", _role), do: {:ok, "operations.activation"}
  def required_dimension("model_request", _role), do: {:ok, "model_requests"}
  def required_dimension("validation", _role), do: {:ok, "validations"}
  def required_dimension(_operation, _role), do: {:error, :operation_dimension_mismatch}
end
