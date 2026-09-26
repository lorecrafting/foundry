defmodule Foundry.DurableStore.Protected.Rows do
  @moduledoc false

  alias Foundry.DurableStore.{Database, Encoding}

  @operation_types ~w(set_policy set_control append_inbox seal_inbox grant_ledger delegate_allocation return_allocation reserve release_reservation close_generation reset_generation create_effect claim_effect reclaim_claim issue_claim cancel_effect settle_claim close_attempt)
  @closed_effect_statuses ~w(succeeded failed non_started cancelled)

  def operation_types, do: @operation_types
  def closed_effect_statuses, do: @closed_effect_statuses

  def nonnegative_integer?(value), do: is_integer(value) and value >= 0
  def positive_integer?(value), do: is_integer(value) and value > 0

  def subtree_ledgers(conn, ledger_id, generation) do
    sql =
      "WITH RECURSIVE tree(ledger_id, generation) AS (" <>
        "SELECT ledger_id, generation FROM root_ledgers WHERE ledger_id = ? AND generation = ? " <>
        "UNION ALL SELECT c.ledger_id, c.generation FROM root_ledgers c JOIN tree p " <>
        "ON c.parent_ledger_id = p.ledger_id AND c.parent_generation = p.generation) " <>
        "SELECT l.ledger_id, l.generation, l.parent_ledger_id, l.parent_generation, l.dimension, l.revision, l.status, l.authorized, l.available, l.held, l.consumed, l.delegated, l.retired " <>
        "FROM root_ledgers l JOIN tree t ON t.ledger_id = l.ledger_id AND t.generation = l.generation " <>
        "ORDER BY l.ledger_id, l.generation"

    with :ok <- identity(ledger_id),
         true <- is_integer(generation) and generation >= 0,
         {:ok, rows} <- Database.query(conn, sql, [ledger_id, generation]) do
      {:ok, Enum.map(rows, &ledger_from_row/1)}
    else
      false -> {:error, :invalid_ledger_generation}
      {:error, _reason} = error -> error
    end
  end

  def request_digest(actor_id, request),
    do:
      Encoding.semantic_digest("foundry-protected-command-v1", %{
        "actor_id" => actor_id,
        "request" => request
      })

  def load_inbox(conn, id) do
    case load_existing_inbox(conn, id) do
      {:ok, inbox} -> {:ok, inbox}
      {:error, :not_found} -> {:ok, :absent}
      error -> error
    end
  end

  def load_existing_inbox(conn, id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT actor_id, revision, last_sequence, sealed_sequence FROM authenticated_inboxes WHERE execution_id = ?",
             [id]
           ) do
      case rows do
        [] ->
          {:error, :not_found}

        [[actor, revision, last, sealed]] ->
          {:ok,
           %{actor_id: actor, revision: revision, last_sequence: last, sealed_sequence: sealed}}

        _ ->
          {:error, :duplicate_protected_identity}
      end
    end
  end

  def write_inbox_head(conn, :absent, id, actor_id, sequence) do
    inbox = %{actor_id: actor_id, revision: 0, last_sequence: sequence, sealed_sequence: nil}

    with {:ok, bytes} <- encode(inbox_state(id, inbox)) do
      Database.execute(
        conn,
        "INSERT INTO authenticated_inboxes(execution_id, actor_id, revision, last_sequence, sealed_sequence, state) VALUES (?, ?, 0, ?, NULL, ?)",
        [id, inbox.actor_id, sequence, {:blob, bytes}]
      )
    end
  end

  def write_inbox_head(conn, current, id, actor_id, sequence) do
    next = %{current | revision: current.revision + 1, last_sequence: sequence}

    with true <- current.actor_id == actor_id,
         {:ok, bytes} <- encode(inbox_state(id, next)) do
      Database.execute(
        conn,
        "UPDATE authenticated_inboxes SET revision = ?, last_sequence = ?, state = ? WHERE execution_id = ? AND revision = ?",
        [next.revision, sequence, {:blob, bytes}, id, current.revision]
      )
    else
      false -> {:error, :inbox_actor_conflict}
      {:error, _reason} = error -> error
    end
  end

  def inbox_state(id, inbox) do
    %{
      "schema_version" => 1,
      "execution_id" => id,
      "actor_id" => inbox.actor_id,
      "revision" => inbox.revision,
      "last_sequence" => inbox.last_sequence,
      "sealed_sequence" => inbox.sealed_sequence
    }
  end

  def inbox_fact(conn, id) do
    with :ok <- identity(id),
         {:ok, inbox} <- load_existing_inbox(conn, id),
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT sequence, item_kind, disposition, item_digest, item FROM authenticated_inbox_items WHERE execution_id = ? ORDER BY sequence",
             [id]
           ),
         {:ok, items} <- decode_inbox_items(rows),
         resolution <- inbox_resolution(inbox, items) do
      {:ok,
       inbox_state(id, inbox)
       |> Map.put("items", items)
       |> Map.put("resolution", resolution)}
    end
  end

  defp decode_inbox_items(rows) do
    Enum.reduce_while(rows, {:ok, []}, fn [sequence, kind, disposition, digest, bytes],
                                          {:ok, acc} ->
      case decode(bytes) do
        {:ok,
         %{
           "sequence" => ^sequence,
           "item_kind" => ^kind,
           "disposition" => ^disposition,
           "item_digest" => ^digest
         } = item} ->
          {:cont, {:ok, [item | acc]}}

        _ ->
          {:halt, {:error, :corrupt_inbox_item}}
      end
    end)
    |> then(fn
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end)
  end

  defp inbox_resolution(%{sealed_sequence: nil}, _items), do: %{"status" => "open"}

  defp inbox_resolution(_inbox, items) do
    accepted = Enum.filter(items, &(&1["disposition"] == "accepted"))

    case Enum.find(accepted, &(&1["item_kind"] == "result")) do
      nil ->
        case Enum.find(accepted, &(&1["item_kind"] == "exit")) do
          nil ->
            %{"status" => "sealed_without_result_or_exit"}

          exit ->
            %{"status" => "exit", "sequence" => exit["sequence"], "payload" => exit["payload"]}
        end

      result ->
        %{"status" => "result", "sequence" => result["sequence"], "payload" => result["payload"]}
    end
  end

  def load_simple_optional(conn, table, column, id) do
    case load_simple(conn, table, column, id) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} when reason in [:not_found, :policy_not_found, :control_not_found] ->
        {:ok, :absent}

      error ->
        error
    end
  end

  def load_simple(conn, table, column, id) do
    with {:ok, rows} <-
           Database.query(conn, "SELECT revision, state FROM #{table} WHERE #{column} = ?", [id]) do
      case rows do
        [] ->
          {:error, if(table == "root_policies", do: :policy_not_found, else: :control_not_found)}

        [[revision, bytes]] ->
          with {:ok, state} <- decode(bytes),
               do: {:ok, %{revision: revision, value: state["value"]}}

        _ ->
          {:error, :duplicate_protected_identity}
      end
    end
  end

  def write_simple(conn, table, column, id, revision, bytes, :absent) do
    Database.execute(
      conn,
      "INSERT INTO #{table}(#{column}, revision, state) VALUES (?, ?, ?)",
      [id, revision, {:blob, bytes}]
    )
  end

  def write_simple(conn, table, column, id, revision, bytes, current) do
    Database.execute(
      conn,
      "UPDATE #{table} SET revision = ?, state = ? WHERE #{column} = ? AND revision = ?",
      [revision, {:blob, bytes}, id, current.revision]
    )
  end

  def insert_simple_history(
        conn,
        "root_policies",
        "policy_id",
        id,
        revision,
        command_id,
        bytes
      ) do
    insert_history_row(
      conn,
      "root_policy_history",
      "policy_id",
      id,
      revision,
      command_id,
      bytes
    )
  end

  def insert_simple_history(
        conn,
        "root_controls",
        "control_id",
        id,
        revision,
        command_id,
        bytes
      ) do
    insert_history_row(
      conn,
      "root_control_history",
      "control_id",
      id,
      revision,
      command_id,
      bytes
    )
  end

  defp insert_history_row(conn, table, column, id, revision, command_id, bytes) do
    prior = if revision == 0, do: nil, else: revision - 1

    Database.execute(
      conn,
      "INSERT INTO #{table}(#{column}, revision, prior_revision, command_id, state) VALUES (?, ?, ?, ?, ?)",
      [id, revision, prior, command_id, {:blob, bytes}]
    )
  end

  def load_ledger(conn, id, generation) do
    with :ok <- identity(id),
         true <- is_integer(generation) and generation >= 0,
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT ledger_id, generation, parent_ledger_id, parent_generation, dimension, revision, status, authorized, available, held, consumed, delegated, retired FROM root_ledgers WHERE ledger_id = ? AND generation = ?",
             [id, generation]
           ) do
      case rows do
        [] -> {:ok, :absent}
        [row] -> {:ok, ledger_from_row(row)}
        _ -> {:error, :duplicate_protected_identity}
      end
    else
      false -> {:error, :invalid_ledger_identity}
      {:error, _reason} = error -> error
    end
  end

  def load_existing_ledger(conn, id, generation) do
    case load_ledger(conn, id, generation) do
      {:ok, :absent} -> {:error, :not_found}
      other -> other
    end
  end

  def current_generation(conn, id) do
    with :ok <- identity(id),
         {:ok, rows} <-
           Database.query(conn, "SELECT max(generation) FROM root_ledgers WHERE ledger_id = ?", [
             id
           ]) do
      case rows do
        [[generation]] when is_integer(generation) -> {:ok, generation}
        [[nil]] -> {:error, :not_found}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  def ledger_from_row([
        id,
        generation,
        parent_id,
        parent_generation,
        dimension,
        revision,
        status,
        authorized,
        available,
        held,
        consumed,
        delegated,
        retired
      ]) do
    %{
      ledger_id: id,
      generation: generation,
      parent_ledger_id: parent_id,
      parent_generation: parent_generation,
      dimension: dimension,
      revision: revision,
      status: status,
      authorized: authorized,
      available: available,
      held: held,
      consumed: consumed,
      delegated: delegated,
      retired: retired
    }
  end

  def public_ledger(ledger) do
    ledger
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.put("schema_version", 1)
  end

  def insert_ledger(conn, ledger) do
    with {:ok, bytes} <- encode(public_ledger(ledger)) do
      Database.execute(
        conn,
        "INSERT INTO root_ledgers(ledger_id, generation, parent_ledger_id, parent_generation, dimension, revision, status, authorized, available, held, consumed, delegated, retired, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ledger_params(ledger) ++ [{:blob, bytes}]
      )
    end
  end

  def update_ledger(conn, old, next) do
    with true <- conserved?(next),
         {:ok, bytes} <- encode(public_ledger(next)),
         :ok <-
           Database.execute(
             conn,
             "UPDATE root_ledgers SET revision = ?, status = ?, authorized = ?, available = ?, held = ?, consumed = ?, delegated = ?, retired = ?, state = ? WHERE ledger_id = ? AND generation = ? AND revision = ?",
             [
               next.revision,
               next.status,
               next.authorized,
               next.available,
               next.held,
               next.consumed,
               next.delegated,
               next.retired,
               {:blob, bytes},
               old.ledger_id,
               old.generation,
               old.revision
             ]
           ),
         {:ok, [[1]]} <- Database.query(conn, "SELECT changes()") do
      :ok
    else
      false -> {:error, :ledger_conservation_violation}
      {:ok, _rows} -> {:error, :ledger_revision_conflict}
      {:error, _reason} = error -> error
    end
  end

  defp ledger_params(ledger) do
    [
      ledger.ledger_id,
      ledger.generation,
      ledger.parent_ledger_id,
      ledger.parent_generation,
      ledger.dimension,
      ledger.revision,
      ledger.status,
      ledger.authorized,
      ledger.available,
      ledger.held,
      ledger.consumed,
      ledger.delegated,
      ledger.retired
    ]
  end

  def conserved?(ledger),
    do:
      ledger.authorized ==
        ledger.available + ledger.held + ledger.consumed + ledger.delegated + ledger.retired and
        Enum.all?(
          [
            ledger.authorized,
            ledger.available,
            ledger.held,
            ledger.consumed,
            ledger.delegated,
            ledger.retired
          ],
          &(&1 >= 0)
        )

  def insert_reservation(conn, reservation) do
    with {:ok, bytes} <- encode(public_reservation(reservation)) do
      Database.execute(
        conn,
        "INSERT INTO root_reservations(reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          reservation.reservation_id,
          reservation.ledger_id,
          reservation.generation,
          reservation.dimension,
          reservation.owner_kind,
          reservation.owner_id,
          reservation.units,
          reservation.revision,
          reservation.status,
          reservation.claim_id,
          {:blob, bytes}
        ]
      )
    end
  end

  def load_reservation(conn, id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations WHERE reservation_id = ?",
             [id]
           ) do
      case rows do
        [] -> {:error, :not_found}
        [row] -> {:ok, reservation_from_row(row)}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  def reservation_from_row([
        id,
        ledger_id,
        generation,
        dimension,
        owner_kind,
        owner_id,
        units,
        revision,
        status,
        claim_id
      ]) do
    %{
      reservation_id: id,
      ledger_id: ledger_id,
      generation: generation,
      dimension: dimension,
      owner_kind: owner_kind,
      owner_id: owner_id,
      units: units,
      revision: revision,
      status: status,
      claim_id: claim_id
    }
  end

  def public_reservation(reservation) do
    reservation
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.put("schema_version", 1)
  end

  def update_reservation(conn, old, next) do
    with {:ok, bytes} <- encode(public_reservation(next)),
         :ok <-
           Database.execute(
             conn,
             "UPDATE root_reservations SET revision = ?, status = ?, claim_id = ?, state = ? WHERE reservation_id = ? AND revision = ?",
             [
               next.revision,
               next.status,
               next.claim_id,
               {:blob, bytes},
               old.reservation_id,
               old.revision
             ]
           ) do
      :ok
    end
  end

  def normalize_lease_specs(specs) do
    Enum.reduce_while(specs, {:ok, []}, fn spec, {:ok, acc} ->
      with {:ok, spec} <- string_map(spec),
           :ok <- exact_keys(spec, ~w(lease_id resource_id)),
           :ok <- identities(spec, ~w(lease_id resource_id)) do
        {:cont, {:ok, [spec | acc]}}
      else
        _ -> {:halt, {:error, :invalid_lease_spec}}
      end
    end)
    |> then(fn
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end)
  end

  # Filtered by scope as well, so if an objective scope becomes admissible (O0 U9) a
  # ticket closure cannot silently widen over it (review of 03aff5db).
  def attempt_effects(conn, scope, ticket_id, attempt_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT effect_id FROM root_effects WHERE scope = ? AND ticket_id = ? AND attempt_id = ? ORDER BY effect_id",
             [scope, ticket_id, attempt_id]
           ) do
      Enum.reduce_while(rows, {:ok, []}, fn [id], {:ok, acc} ->
        case load_effect(conn, id) do
          {:ok, effect} -> {:cont, {:ok, acc ++ [effect]}}
          error -> {:halt, error}
        end
      end)
    end
  end

  # The activated set, not every reservation naming the effect as owner: a stray proposed
  # reservation holds no units and must not block the close (review F3).
  def attempt_reservations(conn, effects) do
    effects
    |> Enum.flat_map(&Map.get(&1, :reservation_ids, []))
    |> Enum.reduce_while({:ok, []}, fn id, {:ok, acc} ->
      case load_reservation(conn, id) do
        {:ok, reservation} -> {:cont, {:ok, acc ++ [reservation]}}
        error -> {:halt, error}
      end
    end)
  end

  def assignment_id(ticket_id, attempt_id, role),
    do: Enum.join([ticket_id, attempt_id, role], ":")

  def insert_effect(conn, effect) do
    with {:ok, bytes} <- encode(public_effect(effect)) do
      Database.execute(
        conn,
        "INSERT INTO root_effects(effect_id, request_digest, policy_id, policy_revision, control_id, control_revision, operation, scope, ticket_id, attempt_id, execution_id, status, revision, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          effect.effect_id,
          effect.request_digest,
          effect.policy_id,
          effect.policy_revision,
          effect.control_id,
          effect.control_revision,
          effect.operation,
          effect.scope,
          effect.ticket_id,
          effect.attempt_id,
          effect.execution_id,
          effect.status,
          effect.revision,
          {:blob, bytes}
        ]
      )
    end
  end

  def load_effect(conn, id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT effect_id, request_digest, policy_id, policy_revision, control_id, control_revision, operation, scope, ticket_id, attempt_id, execution_id, status, revision, state FROM root_effects WHERE effect_id = ?",
             [id]
           ) do
      case rows do
        [] ->
          {:error, :not_found}

        [
          [
            effect_id,
            request_digest,
            policy_id,
            policy_revision,
            control_id,
            control_revision,
            operation,
            scope,
            ticket_id,
            attempt_id,
            execution_id,
            status,
            revision,
            bytes
          ]
        ] ->
          with {:ok, state} <- decode(bytes) do
            {:ok,
             %{
               effect_id: effect_id,
               request_digest: request_digest,
               policy_id: policy_id,
               policy_revision: policy_revision,
               control_id: control_id,
               control_revision: control_revision,
               operation: operation,
               scope: scope,
               ticket_id: ticket_id,
               attempt_id: attempt_id,
               execution_id: execution_id,
               assignment_id: state["assignment_id"],
               role: state["role"],
               phase_generation: state["phase_generation"],
               operation_ordinal: state["operation_ordinal"],
               predecessor_effect_id: state["predecessor_effect_id"],
               request_id: state["request_id"],
               issuer: state["issuer"],
               channel: state["channel"],
               profile: state["profile"],
               deadline: state["deadline"],
               status: status,
               revision: revision,
               reservation_ids: state["reservation_ids"] || [],
               lease_specs: state["lease_specs"] || []
             }}
          end

        _ ->
          {:error, :duplicate_protected_identity}
      end
    end
  end

  def public_effect(effect) do
    %{
      "schema_version" => 1,
      "effect_id" => effect.effect_id,
      "request_digest" => effect.request_digest,
      "policy_id" => effect.policy_id,
      "policy_revision" => effect.policy_revision,
      "control_id" => effect.control_id,
      "control_revision" => effect.control_revision,
      "operation" => effect.operation,
      "scope" => effect.scope,
      "ticket_id" => effect.ticket_id,
      "attempt_id" => effect.attempt_id,
      "execution_id" => effect.execution_id,
      "assignment_id" => Map.get(effect, :assignment_id),
      "role" => Map.get(effect, :role),
      "phase_generation" => Map.get(effect, :phase_generation),
      "operation_ordinal" => Map.get(effect, :operation_ordinal),
      "predecessor_effect_id" => Map.get(effect, :predecessor_effect_id),
      "request_id" => Map.get(effect, :request_id),
      "issuer" => Map.get(effect, :issuer),
      "channel" => Map.get(effect, :channel),
      "profile" => Map.get(effect, :profile),
      "deadline" => Map.get(effect, :deadline),
      "status" => effect.status,
      "revision" => effect.revision,
      "reservation_ids" => Map.get(effect, :reservation_ids, []),
      "lease_specs" => Map.get(effect, :lease_specs, [])
    }
  end

  def update_effect(conn, old, next) do
    with {:ok, bytes} <- encode(public_effect(next)),
         :ok <-
           Database.execute(
             conn,
             "UPDATE root_effects SET status = ?, revision = ?, state = ? WHERE effect_id = ? AND revision = ?",
             [next.status, next.revision, {:blob, bytes}, old.effect_id, old.revision]
           ) do
      :ok
    end
  end

  def insert_claim(conn, claim) do
    with {:ok, bytes} <- encode(public_claim(claim)) do
      Database.execute(
        conn,
        "INSERT INTO root_claims(claim_id, effect_id, writer_epoch, status, revision, state) VALUES (?, ?, ?, ?, ?, ?)",
        [
          claim.claim_id,
          claim.effect_id,
          claim.writer_epoch,
          claim.status,
          claim.revision,
          {:blob, bytes}
        ]
      )
    end
  end

  def load_claim(conn, id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT claim_id, effect_id, writer_epoch, status, revision FROM root_claims WHERE claim_id = ?",
             [id]
           ) do
      case rows do
        [] ->
          {:error, :not_found}

        [[claim_id, effect_id, epoch, status, revision]] ->
          {:ok,
           %{
             claim_id: claim_id,
             effect_id: effect_id,
             writer_epoch: epoch,
             status: status,
             revision: revision
           }}

        _ ->
          {:error, :duplicate_protected_identity}
      end
    end
  end

  def public_claim(claim) do
    claim
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.put("schema_version", 1)
  end

  def update_claim(conn, old, next) do
    with {:ok, bytes} <- encode(public_claim(next)) do
      Database.execute(
        conn,
        "UPDATE root_claims SET writer_epoch = ?, status = ?, revision = ?, state = ? WHERE claim_id = ? AND revision = ?",
        [
          next.writer_epoch,
          next.status,
          next.revision,
          {:blob, bytes},
          old.claim_id,
          old.revision
        ]
      )
    end
  end

  def reservations_for_effect(conn, effect_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations WHERE owner_kind = 'effect' AND owner_id = ? ORDER BY reservation_id",
             [effect_id]
           ) do
      {:ok, Enum.map(rows, &reservation_from_row/1)}
    end
  end

  def reservations_for_claim(conn, claim_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations WHERE claim_id = ? ORDER BY reservation_id",
             [claim_id]
           ) do
      {:ok, Enum.map(rows, &reservation_from_row/1)}
    end
  end

  def public_lease(lease) do
    lease
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.put("schema_version", 1)
  end

  def receipt_digest(operation) do
    Encoding.semantic_digest("foundry-root-receipt-v1", %{
      "claim_id" => operation["claim_id"],
      "request_id" => operation["request_id"],
      "outcome" => operation["outcome"],
      "proof" => operation["proof"],
      "payload" => operation["payload"]
    })
  end

  def receipt(operation, digest, claim_id) do
    %{
      receipt_id: operation["receipt_id"],
      claim_id: claim_id,
      request_id: operation["request_id"],
      outcome: operation["outcome"],
      receipt_digest: digest,
      proof: operation["proof"],
      payload: operation["payload"]
    }
  end

  def public_receipt(receipt) do
    receipt
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
    |> Map.put("schema_version", 1)
  end

  def insert_receipt(conn, receipt) do
    with {:ok, bytes} <- encode(public_receipt(receipt)) do
      Database.execute(
        conn,
        "INSERT INTO root_receipts(receipt_id, claim_id, request_id, outcome, receipt_digest, state) VALUES (?, ?, ?, ?, ?, ?)",
        [
          receipt.receipt_id,
          receipt.claim_id,
          receipt.request_id,
          receipt.outcome,
          receipt.receipt_digest,
          {:blob, bytes}
        ]
      )
    end
  end

  def receipts_for_claim(conn, claim_id) do
    receipt_rows(
      conn,
      "SELECT receipt_id, claim_id, request_id, outcome, receipt_digest, state FROM root_receipts WHERE claim_id = ? ORDER BY receipt_id",
      [claim_id]
    )
  end

  def receipts_for_request(conn, request_id) do
    receipt_rows(
      conn,
      "SELECT receipt_id, claim_id, request_id, outcome, receipt_digest, state FROM root_receipts WHERE request_id = ? ORDER BY receipt_id",
      [request_id]
    )
  end

  def receipts_for_id(conn, receipt_id) do
    receipt_rows(
      conn,
      "SELECT receipt_id, claim_id, request_id, outcome, receipt_digest, state FROM root_receipts WHERE receipt_id = ? ORDER BY receipt_id",
      [receipt_id]
    )
  end

  defp receipt_rows(conn, sql, parameters) do
    with {:ok, rows} <- Database.query(conn, sql, parameters) do
      Enum.reduce_while(rows, {:ok, []}, fn [id, claim, request, outcome, digest, bytes],
                                            {:ok, acc} ->
        case decode(bytes) do
          {:ok, state} ->
            value = %{
              receipt_id: id,
              claim_id: claim,
              request_id: request,
              outcome: outcome,
              receipt_digest: digest,
              proof: state["proof"],
              payload: state["payload"]
            }

            {:cont, {:ok, [value | acc]}}

          error ->
            {:halt, error}
        end
      end)
      |> then(fn
        {:ok, values} -> {:ok, Enum.reverse(values)}
        error -> error
      end)
    end
  end

  def settlement_proof("non_started", "issuer_quiescent"), do: :ok
  def settlement_proof("unknown", "outcome_unknown"), do: :ok
  def settlement_proof(outcome, "delivered") when outcome in ~w(succeeded failed), do: :ok
  def settlement_proof(_outcome, _proof), do: {:error, :invalid_receipt_proof}

  def ledger_facts_for_reservations(conn, reservations) do
    reservations
    |> Enum.map(&{&1.ledger_id, &1.generation})
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn {id, generation}, {:ok, acc} ->
      case load_existing_ledger(conn, id, generation) do
        {:ok, ledger} -> {:cont, {:ok, [public_ledger(ledger) | acc]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, ledgers} -> {:ok, Enum.reverse(ledgers)}
      error -> error
    end)
  end

  def ledger_fact(conn, id, generation) do
    with {:ok, ledger} <- load_existing_ledger(conn, id, generation),
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations WHERE ledger_id = ? AND generation = ? ORDER BY reservation_id",
             [id, generation]
           ) do
      {:ok,
       public_ledger(ledger)
       |> Map.put(
         "reservations",
         Enum.map(rows, &(reservation_from_row(&1) |> public_reservation()))
       )}
    end
  end

  def encode(value), do: Encoding.json(value)

  def decode(bytes) when is_binary(bytes) do
    try do
      case :json.decode(bytes) do
        value when is_map(value) -> {:ok, normalize_decoded(value)}
        _ -> {:error, :invalid_protected_record}
      end
    rescue
      _ -> {:error, :invalid_protected_record}
    end
  end

  def decode(_bytes), do: {:error, :invalid_protected_record}

  defp normalize_decoded(:null), do: nil
  defp normalize_decoded(value) when is_list(value), do: Enum.map(value, &normalize_decoded/1)

  defp normalize_decoded(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, normalize_decoded(item)} end)

  defp normalize_decoded(value), do: value

  def string_map(value) when is_map(value) and not is_struct(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {key, item}, {:ok, acc} ->
      normalized_key = if is_atom(key), do: Atom.to_string(key), else: key

      if is_binary(normalized_key) and not Map.has_key?(acc, normalized_key) do
        {:cont, {:ok, Map.put(acc, normalized_key, item)}}
      else
        {:halt, {:error, :invalid_or_duplicate_key}}
      end
    end)
  end

  def string_map(_value), do: {:error, :not_a_map}

  def exact_keys(map, expected) do
    if Enum.sort(Map.keys(map)) == Enum.sort(expected), do: :ok, else: {:error, :invalid_fields}
  end

  def identities(map, keys) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      case identity(map[key]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  def identity(value) when is_binary(value) and value != "" do
    if String.valid?(value), do: :ok, else: {:error, :invalid_identity}
  end

  def identity(_value), do: {:error, :invalid_identity}

  def plain_map?(value), do: is_map(value) and not is_struct(value) and plain_value?(value)

  def plain_value?(value)
      when is_binary(value) or is_integer(value) or is_boolean(value) or is_nil(value),
      do: true

  def plain_value?(value) when is_list(value),
    do: proper_list?(value) and Enum.all?(value, &plain_value?/1)

  def plain_value?(value) when is_map(value) and not is_struct(value),
    do: Enum.all?(value, fn {key, item} -> is_binary(key) and plain_value?(item) end)

  def plain_value?(_value), do: false

  def proper_list?(value) do
    _ = length(value)
    true
  rescue
    ArgumentError -> false
  end
end
