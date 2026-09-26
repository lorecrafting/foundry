defmodule Foundry.DurableStore.ProtectedPrimitives do
  @moduledoc false

  alias Foundry.DurableStore.Database

  import Foundry.DurableStore.Protected.Rows,
    only: [
      decode: 1,
      encode: 1,
      exact_keys: 2,
      identities: 2,
      identity: 1,
      nonnegative_integer?: 1,
      plain_map?: 1,
      positive_integer?: 1,
      proper_list?: 1,
      request_digest: 2,
      string_map: 1
    ]

  import Foundry.DurableStore.Protected.ReadSet,
    only: [complete_read_set: 3, normalize_read_set: 1, required_reads: 2]

  import Foundry.DurableStore.Protected.Operations, only: [apply_operation: 2]

  @operation_types Foundry.DurableStore.Protected.Rows.operation_types()

  defdelegate required_bundle_prestate_revisions(conn, operation, prior_operations),
    to: Foundry.DurableStore.Protected.ReadSet

  defdelegate persist_nonstart_settlement(conn, operation, facts),
    to: Foundry.DurableStore.Protected.Operations

  defdelegate infrastructure_discriminator_at_revision(conn, effect_id, settlement),
    to: Foundry.DurableStore.Protected.Guards

  defdelegate authority_mode(conn), to: Foundry.DurableStore.Protected.Reads
  defdelegate query(conn, query), to: Foundry.DurableStore.Protected.Reads
  defdelegate snapshot(conn, writer_epoch), to: Foundry.DurableStore.Protected.Reads
  defdelegate validate(conn), to: Foundry.DurableStore.Protected.RestartCheck

  @doc false
  def supported_operation_type?(type), do: type in @operation_types

  @doc false
  def execute(conn, actor_id, request, writer_epoch, fault \\ nil) do
    with :ok <- identity(actor_id),
         :ok <- identity(writer_epoch),
         {:ok, request} <- normalize_request(request),
         :ok <- validate_public_command_identity(conn, request["command_id"]),
         {:ok, digest} <- request_digest(actor_id, request) do
      case existing_command(conn, request["command_id"], actor_id, digest) do
        {:ok, result} ->
          {:ok, result, :idempotent}

        {:error, :not_found} ->
          with :ok <- validate_operation_envelope(request["operation"]) do
            execute_new(conn, actor_id, request, writer_epoch, digest, fault)
            |> case do
              {:ok, result} ->
                if fault == :after_commit_before_reply,
                  do: {:error, {:storage_unavailable, :injected_after_commit_before_reply}},
                  else: {:ok, result, :committed}

              {:error, :invalid_fields} ->
                {:error, :invalid_protected_request}

              {:error, :invalid_identity} ->
                {:error, :invalid_protected_request}

              {:error, reason} ->
                {:error, {:storage_unavailable, reason}}
            end
          else
            _ -> {:error, :invalid_protected_request}
          end

        {:error, _reason} = error ->
          error
      end
    end
  end

  @doc false
  def execute_in_transaction(conn, actor_id, request, writer_epoch) do
    with :ok <- identity(actor_id),
         :ok <- identity(writer_epoch),
         {:ok, request} <- normalize_request(request),
         {:ok, digest} <- request_digest(actor_id, request),
         :ok <- validate_operation_envelope(request["operation"]) do
      case existing_command(conn, request["command_id"], actor_id, digest) do
        {:ok, result} ->
          {:ok, result, :idempotent}

        {:error, :not_found} ->
          case apply_new(conn, actor_id, request, writer_epoch) do
            {:ok, facts} ->
              with {:ok, result} <-
                     persist_result(
                       conn,
                       actor_id,
                       request,
                       digest,
                       "accepted",
                       nil,
                       facts
                     ) do
                {:ok, result, :accepted}
              end

            {:quarantine, reason, facts} ->
              with {:ok, result} <-
                     persist_result(
                       conn,
                       actor_id,
                       request,
                       digest,
                       "rejected",
                       Atom.to_string(reason),
                       facts
                     ) do
                {:ok, result, :quarantined}
              end

            {:reject, reason, facts} ->
              with {:ok, result} <-
                     persist_result(
                       conn,
                       actor_id,
                       request,
                       digest,
                       "rejected",
                       Atom.to_string(reason),
                       facts
                     ) do
                {:ok, result, :rejected}
              end

            {:error, _reason} = error ->
              error
          end

        {:error, _reason} = error ->
          error
      end
    else
      _ -> {:error, :invalid_protected_request}
    end
  end

  @doc false
  def required_revisions(conn, operation), do: required_reads(conn, operation)

  defp execute_new(conn, actor_id, request, writer_epoch, digest, fault) do
    Database.transaction(conn, fn ->
      case apply_new(conn, actor_id, request, writer_epoch) do
        {:ok, facts} ->
          persist_committed_result(
            conn,
            actor_id,
            request,
            digest,
            "accepted",
            nil,
            facts,
            fault
          )

        {:quarantine, reason, facts} ->
          persist_committed_result(
            conn,
            actor_id,
            request,
            digest,
            "rejected",
            Atom.to_string(reason),
            facts,
            fault
          )

        {:reject, reason, facts} ->
          {:error, {:semantic_rejection, reason, facts}}

        {:error, _reason} = error ->
          error
      end
    end)
    |> case do
      {:error, {:semantic_rejection, reason, facts}} ->
        Database.transaction(conn, fn ->
          persist_committed_result(
            conn,
            actor_id,
            request,
            digest,
            "rejected",
            Atom.to_string(reason),
            facts,
            fault
          )
        end)

      result ->
        result
    end
  end

  defp persist_committed_result(
         conn,
         actor_id,
         request,
         digest,
         disposition,
         reason,
         facts,
         fault
       ) do
    with {:ok, result} <-
           persist_result(conn, actor_id, request, digest, disposition, reason, facts),
         :ok <- persist_v1_operation(conn, request["command_id"]),
         :ok <- inject(fault, :before_commit) do
      {:ok, result}
    end
  end

  defp persist_v1_operation(conn, command_id) do
    Database.execute(
      conn,
      "INSERT INTO durable_operations(owner_kind, owner_id, ordinal, operation_kind, operation_type, request, result) " <>
        "SELECT 'protected_v1', command_id, 0, 'protected', operation, canonical_request, result FROM root_commands WHERE command_id = ?",
      [command_id]
    )
  end

  defp validate_operation_envelope(%{"type" => type} = operation)
       when type in @operation_types do
    identity_fields =
      case type do
        "set_policy" ->
          ~w(policy_id)

        "set_control" ->
          ~w(control_id)

        type when type in ["append_inbox", "seal_inbox"] ->
          ~w(execution_id)

        "grant_ledger" ->
          ~w(ledger_id)

        "delegate_allocation" ->
          ~w(parent_ledger_id child_ledger_id)

        "return_allocation" ->
          ~w(child_ledger_id)

        "reserve" ->
          ~w(reservation_id ledger_id owner_kind owner_id)

        "release_reservation" ->
          ~w(reservation_id)

        "close_generation" ->
          ~w(ledger_id)

        "reset_generation" ->
          ~w(ledger_id)

        "create_effect" ->
          ~w(effect_id operation scope ticket_id attempt_id execution_id policy_id control_id)

        "claim_effect" ->
          ~w(effect_id claim_id writer_epoch)

        "reclaim_claim" ->
          ~w(claim_id prior_writer_epoch new_writer_epoch proof)

        "issue_claim" ->
          ~w(claim_id writer_epoch)

        "cancel_effect" ->
          ~w(effect_id)

        "settle_claim" ->
          ~w(claim_id receipt_id request_id outcome proof)

        "close_attempt" ->
          ~w(scope ticket_id attempt_id)
      end

    with true <- plain_map?(operation),
         :ok <- identities(operation, identity_fields),
         true <- valid_operation_scalars?(type, operation),
         true <- proper_list?(operation["reservation_ids"] || []),
         true <- Enum.all?(operation["reservation_ids"] || [], &is_binary/1),
         true <- proper_list?(operation["leases"] || []),
         true <-
           Enum.all?(operation["leases"] || [], fn lease ->
             plain_map?(lease) and is_binary(lease["lease_id"]) and
               is_binary(lease["resource_id"])
           end) do
      :ok
    else
      _ -> {:error, :invalid_operation_envelope}
    end
  end

  defp validate_operation_envelope(%{"type" => type}) when is_binary(type), do: :ok
  defp validate_operation_envelope(_operation), do: {:error, :invalid_operation_envelope}

  defp valid_operation_scalars?(type, op)
       when type in ["grant_ledger", "reserve"] do
    nonnegative_integer?(op["generation"]) and positive_integer?(op["units"])
  end

  defp valid_operation_scalars?("delegate_allocation", op) do
    nonnegative_integer?(op["parent_generation"]) and
      nonnegative_integer?(op["child_generation"]) and positive_integer?(op["units"])
  end

  defp valid_operation_scalars?("return_allocation", op),
    do: nonnegative_integer?(op["child_generation"]) and positive_integer?(op["units"])

  defp valid_operation_scalars?("close_generation", op),
    do: nonnegative_integer?(op["generation"])

  defp valid_operation_scalars?("reset_generation", op) do
    nonnegative_integer?(op["old_generation"]) and
      nonnegative_integer?(op["new_generation"]) and positive_integer?(op["units"]) and
      (is_nil(op["parent_ledger_id"]) or is_binary(op["parent_ledger_id"])) and
      (is_nil(op["parent_generation"]) or nonnegative_integer?(op["parent_generation"]))
  end

  defp valid_operation_scalars?("append_inbox", op),
    do: positive_integer?(op["sequence"]) and is_binary(op["item_kind"])

  defp valid_operation_scalars?("seal_inbox", op),
    do: nonnegative_integer?(op["last_sequence"])

  defp valid_operation_scalars?("create_effect", op) do
    nonnegative_integer?(op["policy_revision"]) and nonnegative_integer?(op["control_revision"]) and
      plain_map?(op["request"])
  end

  defp valid_operation_scalars?(_type, _op), do: true
  @doc false
  def root_command_id_exists?(conn, command_id) do
    case Database.query(conn, "SELECT 1 FROM root_commands WHERE command_id = ?", [command_id]) do
      {:ok, []} -> false
      {:ok, [[1]]} -> true
      _ -> true
    end
  end

  defp apply_new(conn, actor_id, request, writer_epoch) do
    operation = request["operation"]

    with :ok <- complete_read_set(conn, operation, request["expected_revisions"]) do
      operation =
        case operation["type"] do
          type when type in ["append_inbox", "seal_inbox", "create_effect", "settle_claim"] ->
            Map.put(operation, "authenticated_actor", actor_id)

          type when type in ["set_policy", "set_control"] ->
            Map.put(operation, "root_command_id", request["command_id"])

          type when type in ["claim_effect", "reclaim_claim", "issue_claim"] ->
            Map.put(operation, "current_writer_epoch", writer_epoch)

          _type ->
            operation
        end

      apply_operation(conn, operation)
    else
      {:error, reason} when reason in [:incomplete_read_set, :stale_read_set] ->
        required =
          case required_reads(conn, operation) do
            {:ok, reads} -> reads
            _ -> %{}
          end

        {:reject, reason, %{"required_revisions" => required}}

      {:error, _reason} = error ->
        error
    end
  end

  defp inject(:before_commit, :before_commit), do: {:error, :injected_crash_before_commit}
  defp inject({:halt, :before_commit}, :before_commit), do: System.halt(71)
  defp inject(_fault, _point), do: :ok

  defp normalize_request(request) do
    with {:ok, request} <- string_map(request),
         :ok <- exact_keys(request, ~w(schema_version command_id expected_revisions operation)),
         1 <- request["schema_version"],
         :ok <- identity(request["command_id"]),
         {:ok, _reads} <- normalize_read_set(request["expected_revisions"]),
         {:ok, operation} <- string_map(request["operation"]),
         type when type in @operation_types <- operation["type"] do
      {:ok, Map.put(request, "operation", operation)}
    else
      {:error, _reason} = error -> error
      _ -> {:error, :invalid_protected_command}
    end
  end

  defp validate_public_command_identity(conn, command_id) do
    with false <- String.starts_with?(command_id, "atomic-v2/"),
         {:ok, [[domain_count]]} <-
           Database.query(conn, "SELECT count(*) FROM commands WHERE command_id = ?", [command_id]),
         true <- domain_count == 0 do
      :ok
    else
      _ -> {:error, :idempotency_conflict}
    end
  end

  defp existing_command(conn, command_id, actor_id, digest) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT actor_id, request_digest, result FROM root_commands WHERE command_id = ?",
             [command_id]
           ) do
      case rows do
        [] ->
          case Database.query(conn, "SELECT 1 FROM commands WHERE command_id = ?", [command_id]) do
            {:ok, []} -> {:error, :not_found}
            {:ok, _rows} -> {:error, :idempotency_conflict}
            {:error, _reason} = error -> error
          end

        [[^actor_id, ^digest, bytes]] ->
          decode(bytes)

        [[_actor, _digest, _bytes]] ->
          {:error, :idempotency_conflict}

        _ ->
          {:error, :duplicate_protected_identity}
      end
    end
  end

  defp persist_result(conn, actor_id, request, digest, disposition, reason, facts) do
    with {:ok, [[next_seq]]} <-
           Database.query(conn, "SELECT coalesce(max(seq), 0) + 1 FROM root_commands"),
         result <- %{
           "schema_version" => 1,
           "command_id" => request["command_id"],
           "command_sequence" => next_seq,
           "disposition" => disposition,
           "reason_code" => reason,
           "facts" => facts
         },
         {:ok, canonical_request} <-
           encode(%{"actor_id" => actor_id, "schema_version" => 1, "request" => request}),
         {:ok, bytes} <- encode(result),
         :ok <-
           Database.execute(
             conn,
             "INSERT INTO root_commands(seq, command_id, actor_id, request_digest, canonical_request, schema_version, operation, disposition, reason_code, result) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?)",
             [
               next_seq,
               request["command_id"],
               actor_id,
               digest,
               {:blob, canonical_request},
               request["operation"]["type"],
               disposition,
               reason,
               {:blob, bytes}
             ]
           ) do
      {:ok, result}
    end
  end
end
