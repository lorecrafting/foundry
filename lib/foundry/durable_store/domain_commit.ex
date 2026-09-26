defmodule Foundry.DurableStore.DomainCommit do
  @moduledoc false

  alias Foundry.DurableStore.{
    Authority,
    Database,
    Encoding,
    Kernel,
    ProtectedPrimitives,
    RecordCodec,
    TransitionPlan
  }

  @doc false
  def do_transact(conn, actor_id, command, proposal, fault) do
    with {:ok, canonical, digest, normalized_command} <- prepare_command(actor_id, command) do
      command_id = normalized_command["command_id"]

      case existing(conn, command_id, actor_id, digest) do
        {:ok, result} ->
          {:ok, result, :idempotent}

        {:error, :not_found} ->
          case normalize_candidate(proposal) do
            {:ok, normalized} ->
              commit_bundle(
                conn,
                actor_id,
                normalized_command,
                canonical,
                digest,
                normalized,
                fault
              )

            {:error, reason} ->
              {:error, reason}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Every proposal carrier routes through here: plain, verified and atomic. A slot-typed
  # event carries a bound fact that only a plan's binding may supply, so a carrier that
  # holds one is committing a fact it wrote itself (Quint core_boundary F2).
  @doc false
  def normalize_candidate(proposal) do
    case Kernel.normalize_bundle(proposal) do
      {:ok, normalized} ->
        slot_types = TransitionPlan.slot_event_types()

        if Enum.any?(normalized["events"], &(&1["type"] in slot_types)),
          do: {:error, :bound_event_requires_plan},
          else: {:ok, normalized}

      {:error, :projection_transition_bijection} ->
        {:error, {:bundle_rejected, :projection_transition_bijection}}

      {:error, :invalid_projection} ->
        {:error, :invalid_projection_revision}

      result ->
        result
    end
  end

  @doc false
  def prepare_command(actor_id, command) do
    with :ok <- validate_actor(actor_id),
         {:ok, normalized_command} <- RecordCodec.normalize(:command, command),
         {:ok, canonical} <-
           Encoding.canonical(%{
             "domain" => "foundry-command-v1",
             "schema_version" => 1,
             "actor_id" => actor_id,
             "command" => normalized_command
           }) do
      {:ok, canonical, Encoding.digest(canonical), normalized_command}
    end
  end

  defp commit_bundle(conn, actor_id, command, canonical, digest, proposal, fault) do
    transaction_result =
      Database.transaction(conn, fn ->
        case check_expected_revisions(conn, command, proposal) do
          :ok ->
            commit_accepted_bundle(
              conn,
              actor_id,
              command,
              canonical,
              digest,
              proposal,
              fault
            )

          {:error, {:revision_conflict, _key, _expected, _actual} = reason} ->
            commit_rejected_command(conn, actor_id, command, canonical, digest, reason)

          {:error, reason} ->
            {:error, reason}
        end
      end)

    case transaction_result do
      {:ok, {:accepted, result}} ->
        case fault do
          :after_commit_before_reply ->
            {:error, {:outcome_unknown, get(command, "command_id")}}

          {:halt, :after_commit} ->
            System.halt(72)

          _other ->
            {:ok, result, :committed}
        end

      {:ok, {:rejected, result}} ->
        {:ok, result, :rejected}

      {:error, reason} ->
        cond do
          match?({:authority_corrupt, _table, _identity, _why}, reason) -> {:error, reason}
          match?({:storage_unavailable, _why}, reason) -> {:error, reason}
          semantic_rejection?(reason) -> {:error, {:bundle_rejected, reason}}
          true -> {:error, {:storage_unavailable, reason}}
        end
    end
  end

  @doc false
  def commit_accepted_bundle(
        conn,
        actor_id,
        command,
        canonical,
        digest,
        proposal,
        fault,
        durable_owner \\ :domain_v1
      ) do
    with :ok <- inject(fault, :before_write),
         :ok <- insert_input(conn, actor_id, command, canonical, digest),
         :ok <- inject(fault, :after_input),
         :ok <- insert_command(conn, actor_id, command, digest),
         :ok <- inject(fault, :after_command),
         :ok <- insert_events(conn, get(proposal, :events, []), get(command, "command_id")),
         :ok <- inject(fault, :after_events),
         :ok <-
           insert_projections(
             conn,
             get(proposal, :events, []),
             get(proposal, :projections, [])
           ),
         :ok <- inject(fault, :after_projections),
         :ok <-
           insert_intents(conn, get(proposal, :intents, []), get(command, "command_id")),
         :ok <- inject(fault, :after_intents),
         {:ok, committed_seq} <- current_seq(conn),
         {:ok, result} <-
           insert_result(
             conn,
             get(command, "command_id"),
             get(proposal, :result),
             committed_seq
           ),
         :ok <- maybe_persist_v1_domain_operation(conn, command, durable_owner),
         :ok <- inject(fault, :after_result),
         {:ok, _checked} <-
           Authority.read(conn, {
             :touched,
             %{
               command_id: get(command, "command_id"),
               committed_seq: committed_seq,
               revisions: touched_revisions(proposal)
             }
           }),
         :ok <- inject(fault, :before_commit) do
      {:ok, {:accepted, result}}
    end
  end

  @doc false
  def commit_rejected_command(
        conn,
        actor_id,
        command,
        canonical,
        digest,
        reason,
        durable_owner \\ :domain_v1
      ) do
    with :ok <- insert_input(conn, actor_id, command, canonical, digest),
         :ok <- insert_command(conn, actor_id, command, digest),
         {:ok, committed_seq} <- current_seq(conn),
         {:ok, result} <-
           insert_result(
             conn,
             get(command, "command_id"),
             %{
               schema_version: 1,
               disposition: "rejected",
               reason_code: rejection_reason_code(reason)
             },
             committed_seq
           ),
         :ok <- maybe_persist_v1_domain_operation(conn, command, durable_owner),
         {:ok, _checked} <-
           Authority.read(conn, {
             :touched,
             %{
               command_id: get(command, "command_id"),
               committed_seq: committed_seq,
               revisions: []
             }
           }) do
      {:ok, {:rejected, result}}
    end
  end

  defp rejection_reason_code({:revision_conflict, _key, _expected, _actual}),
    do: "revision_conflict"

  defp rejection_reason_code({:atomic, reason}) when is_binary(reason), do: reason

  defp maybe_persist_v1_domain_operation(_conn, _command, :bundle_v2), do: :ok

  defp maybe_persist_v1_domain_operation(conn, command, :domain_v1) do
    Database.execute(
      conn,
      "INSERT INTO durable_operations(owner_kind, owner_id, ordinal, operation_kind, operation_type, request, result) " <>
        "SELECT 'domain_v1', c.command_id, 0, 'domain', c.command_type, i.canonical_request, r.result " <>
        "FROM commands c JOIN inputs i ON i.input_id = c.input_id JOIN command_results r ON r.command_id = c.command_id " <>
        "WHERE c.command_id = ?",
      [command["command_id"]]
    )
  end

  defp insert_input(conn, actor_id, command, canonical, digest) do
    Database.execute(
      conn,
      "INSERT INTO inputs(input_id, actor_id, request_digest, canonical_request, protocol_version) VALUES (?, ?, ?, ?, 1)",
      ["input:" <> get(command, "command_id"), actor_id, digest, {:blob, canonical}]
    )
  end

  defp insert_command(conn, actor_id, command, digest) do
    Database.execute(
      conn,
      "INSERT INTO commands(command_id, input_id, actor_id, request_digest, command_type, protocol_version) VALUES (?, ?, ?, ?, ?, 1)",
      [
        get(command, "command_id"),
        "input:" <> get(command, "command_id"),
        actor_id,
        digest,
        get(command, "type")
      ]
    )
  end

  defp insert_events(conn, events, command_id) do
    reduce_insert(events, fn event ->
      with {:ok, encoded} <- RecordCodec.encode(:event, event),
           {projection_namespace, projection_entity_id} <- event_carrier(event) do
        Database.execute(
          conn,
          "INSERT INTO events(event_id, command_id, schema_version, event_type, projection_namespace, projection_entity_id, event) VALUES (?, ?, 1, ?, ?, ?, ?)",
          [
            get(event, :event_id),
            command_id,
            get(event, :type),
            projection_namespace,
            projection_entity_id,
            {:blob, encoded}
          ]
        )
      end
    end)
  end

  defp event_carrier(event) do
    case get(event, :payload)["projection"] do
      nil -> {nil, nil}
      projection -> {projection["namespace"], projection["entity_id"]}
    end
  end

  defp insert_projections(conn, events, projections) do
    with {:ok, plan} <- RecordCodec.projection_plan(events, projections),
         {:ok, initial} <- projection_initial_state(conn, plan) do
      Enum.reduce_while(plan, {:ok, initial}, fn {carrier, projection} = step, {:ok, state} ->
        key = {projection["namespace"], projection["entity_id"]}

        with {:ok, next} <- RecordCodec.apply_projection(state, step),
             entry <- Map.fetch!(next, key),
             true <-
               entry == %{
                 revision: projection["revision"],
                 last_event_id: projection["last_event_id"],
                 value: projection["value"]
               },
             {:ok, encoded} <- RecordCodec.encode(:projection, projection),
             :ok <- materialize_projection(conn, projection, encoded),
             {:ok, [[1]]} <- Database.query(conn, "SELECT changes()"),
             {:ok, %{value: stored}} <-
               Authority.read(
                 conn,
                 {:materialized_projection, elem(key, 0), elem(key, 1), carrier["event_id"]}
               ),
             true <- stored == projection do
          {:cont, {:ok, next}}
        else
          false -> {:halt, {:error, :projection_materialization_mismatch}}
          {:ok, rows} -> {:halt, {:error, {:projection_cas_failed, rows}}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)
      |> then(fn
        {:ok, _state} -> :ok
        error -> error
      end)
    end
  end

  defp projection_initial_state(conn, plan) do
    plan
    |> Enum.map(fn {_carrier, projection} ->
      {projection["namespace"], projection["entity_id"]}
    end)
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, %{}}, fn {namespace, entity_id} = key, {:ok, state} ->
      case Authority.read(conn, {:materialized_projection, namespace, entity_id, :stored}) do
        {:ok, :absent} ->
          {:cont, {:ok, state}}

        {:ok, %{value: projection}} ->
          entry = %{
            revision: projection["revision"],
            last_event_id: projection["last_event_id"],
            value: projection["value"]
          }

          {:cont, {:ok, Map.put(state, key, entry)}}

        {:error, _reason} = error ->
          {:halt, error}
      end
    end)
  end

  defp materialize_projection(conn, projection, encoded) do
    if projection["expected_revision"] == -1 do
      Database.execute(
        conn,
        "INSERT INTO projections(namespace, entity_id, schema_version, revision, last_event_id, projection) VALUES (?, ?, 1, ?, ?, ?)",
        [
          projection["namespace"],
          projection["entity_id"],
          projection["revision"],
          projection["last_event_id"],
          {:blob, encoded}
        ]
      )
    else
      Database.execute(
        conn,
        "UPDATE projections SET revision = ?, last_event_id = ?, projection = ? WHERE namespace = ? AND entity_id = ? AND revision = ?",
        [
          projection["revision"],
          projection["last_event_id"],
          {:blob, encoded},
          projection["namespace"],
          projection["entity_id"],
          projection["expected_revision"]
        ]
      )
    end
  end

  defp insert_intents(conn, intents, command_id) do
    reduce_insert(intents, fn intent ->
      with {:ok, encoded} <- RecordCodec.encode(:intent, intent) do
        Database.execute(
          conn,
          "INSERT INTO effects(effect_id, command_id, schema_version, request_digest, status, intent) VALUES (?, ?, 1, ?, ?, ?)",
          [
            get(intent, :effect_id),
            command_id,
            get(intent, :request_digest),
            get(intent, :status),
            {:blob, encoded}
          ]
        )
      end
    end)
  end

  defp insert_result(conn, command_id, result, committed_seq) do
    with {:ok, durable} <- RecordCodec.materialize_result(result, committed_seq),
         {:ok, encoded} <- RecordCodec.encode(:result, durable),
         :ok <-
           Database.execute(
             conn,
             "INSERT INTO command_results(command_id, schema_version, disposition, reason_code, result, committed_seq) VALUES (?, 1, ?, ?, ?, ?)",
             [
               command_id,
               get(result, :disposition),
               get(result, :reason_code),
               {:blob, encoded},
               committed_seq
             ]
           ) do
      RecordCodec.decode(:result, encoded)
    end
  end

  defp existing(conn, command_id, actor_id, digest) do
    with {:ok, [[atomic_count]]} <-
           Database.query(conn, "SELECT count(*) FROM atomic_bundles WHERE command_id = ?", [
             command_id
           ]) do
      if atomic_count > 0 or ProtectedPrimitives.root_command_id_exists?(conn, command_id) do
        {:error, :idempotency_conflict}
      else
        case Authority.read(conn, {:command, command_id}) do
          {:ok, :absent} ->
            {:error, :not_found}

          {:ok, %{actor_id: ^actor_id, digest: ^digest, result: result}} ->
            {:ok, result}

          {:ok, %{}} ->
            {:error, :idempotency_conflict}

          {:error, _reason} = error ->
            error
        end
      end
    else
      {:error, _reason} = error -> error
    end
  end

  @doc false
  def fetch_command(conn, command_id) do
    if valid_identity?(command_id) do
      case Authority.read(conn, {:command, command_id}) do
        {:ok, :absent} -> {:error, :not_found}
        {:ok, %{result: result}} -> {:ok, result}
        {:error, _reason} = error -> error
      end
    else
      {:error, :invalid_command_id}
    end
  end

  defp current_seq(conn) do
    case Database.query(conn, "SELECT coalesce(max(seq), 0) FROM events") do
      {:ok, [[seq]]} -> {:ok, seq}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def check_expected_revisions(conn, command, proposal) do
    expected = get(command, "expected_revisions")
    required = required_projection_reads(proposal)

    with true <- Enum.all?(required, fn {key, value} -> Map.get(expected, key) == value end),
         :ok <- validate_projection_read_alignment(proposal, expected) do
      Enum.reduce_while(expected, :ok, fn {key, expected_value}, :ok ->
        case read_revision(conn, key) do
          {:ok, actual} when actual == expected_value -> {:cont, :ok}
          {:ok, actual} -> {:halt, {:error, {:revision_conflict, key, expected_value, actual}}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    else
      false -> {:error, :incomplete_expected_revisions}
      {:error, _reason} = error -> error
    end
  end

  defp required_projection_reads(proposal) do
    Enum.reduce(get(proposal, :projections, []), %{}, fn projection, acc ->
      expected = get(projection, :expected_revision)
      value = if expected == -1, do: "absent", else: expected

      Map.put_new(
        acc,
        projection_key(get(projection, :namespace), get(projection, :entity_id)),
        value
      )
    end)
  end

  defp touched_revisions(proposal) do
    Enum.map(get(proposal, :projections, []), fn projection ->
      {:projection, projection["namespace"], projection["entity_id"]}
    end)
  end

  defp validate_projection_read_alignment(proposal, expected) do
    if Enum.all?(required_projection_reads(proposal), fn {key, expected_value} ->
         Map.get(expected, key) == expected_value
       end),
       do: :ok,
       else: {:error, :projection_read_mismatch}
  end

  defp read_revision(conn, key) when is_binary(key) do
    typed = RecordCodec.decode_revision_key(key)

    case typed do
      {:error, reason} ->
        {:error, {reason, key}}

      {:ok, typed_key} ->
        with {:ok, value} <- Authority.read(conn, {:revision, typed_key}) do
          case value do
            :absent -> {:ok, "absent"}
            %{revision: revision} -> {:ok, revision}
          end
        end
    end
  end

  @doc false
  def projection_key(namespace, entity_id) do
    "projection/" <> encode_key(namespace) <> "/" <> encode_key(entity_id)
  end

  @doc false
  def encode_key(value), do: Base.url_encode64(value, padding: false)

  @doc false
  def validate_actor(actor_id) when is_binary(actor_id) and actor_id != "" do
    if String.valid?(actor_id), do: :ok, else: {:error, :invalid_actor}
  end

  @doc false
  def validate_actor(_actor_id), do: {:error, :invalid_actor}
  defp valid_identity?(value), do: is_binary(value) and value != "" and String.valid?(value)

  defp reduce_insert(values, fun) do
    Enum.reduce_while(values, :ok, fn value, :ok ->
      case fun.(value) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @doc false
  def inject(:write_error, :before_write), do: {:error, :injected_write_error}
  @doc false
  def inject(:full, :before_write), do: {:error, :injected_full}
  @doc false
  def inject(:after_protected, :after_protected), do: {:error, :injected_after_protected}
  @doc false
  def inject(:after_domain, :after_domain), do: {:error, :injected_after_domain}
  @doc false
  def inject(:before_commit, :before_commit), do: {:error, :injected_crash_before_commit}
  @doc false
  def inject({:halt, :before_commit}, :before_commit), do: System.halt(71)
  @doc false
  def inject({:after_insert, point}, point), do: {:error, {:injected_after_insert, point}}
  @doc false
  def inject(_fault, _point), do: :ok

  defp semantic_rejection?(reason) do
    match?({:revision_conflict, _rows}, reason) or
      match?({:revision_conflict, _key, _expected, _actual}, reason) or
      reason in [:incomplete_expected_revisions, :projection_read_mismatch] or
      match?({:unsupported_revision_key, _key}, reason) or
      match?({:invalid_revision_key, _key}, reason)
  end

  defp get(map, key, default \\ nil)

  defp get(map, key, default) when is_atom(key),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))

  defp get(map, key, default) when is_binary(key), do: Map.get(map, key, default)
end
