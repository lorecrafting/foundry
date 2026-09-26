defmodule Foundry.DurableStore.Gateway do
  @moduledoc """
  Protected, single-connection authority gateway.

  The caller supplies only semantic command data and a validated kernel proposal. SQL,
  the connection and protected table layout never cross this process boundary.
  """

  use GenServer

  @capacity_probe_timeout_ms 5_000

  alias Foundry.DurableStore.{
    Authority,
    Capacity,
    Database,
    DomainCommit,
    Maintenance,
    Encoding,
    Owner,
    PathIdentity,
    ProtectedPrimitives,
    RecordCodec,
    TransitionPlan
  }

  def initialize(path, opts \\ []) do
    case PathIdentity.new(path) do
      {:ok, identity} ->
        with :ok <- PathIdentity.validate_new_database(identity),
             {:ok, owner} <- Owner.acquire(identity, opts) do
          try do
            with :ok <- Database.initialize_owned(owner, opts),
                 {:ok, _created} <- PathIdentity.existing(owner.identity.path) do
              :ok
            end
          after
            Owner.release(owner)
          end
        end

      {:error, :target_exists} ->
        {:error, :already_initialized}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def start_link(opts) do
    {gen_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, gen_opts)
  end

  def status(server), do: GenServer.call(server, :status)

  def transact(server, actor_id, command, proposal),
    do: GenServer.call(server, {:transact, actor_id, command, proposal})

  def command(server, command_id), do: GenServer.call(server, {:command, command_id})

  @doc "Executes one capability-authenticated protected semantic command."
  def protected_command(server, capability, actor_id, request),
    do: GenServer.call(server, {:protected_command, capability, actor_id, request})

  @doc "Atomically commits an ordered protected-operation and domain-proposal bundle."
  def atomic_bundle(server, capability, actor_id, envelope),
    do: GenServer.call(server, {:atomic_bundle, capability, actor_id, envelope})

  @doc "Reads a bounded root-derived protected fact without exposing SQL or table names."
  def protected_query(server, capability, query),
    do: GenServer.call(server, {:protected_query, capability, query})

  @doc "Returns bounded store identity, sequence frontiers and typed root pointer slots."
  def protected_snapshot(server, capability),
    do: GenServer.call(server, {:protected_snapshot, capability})

  def counts(server), do: GenServer.call(server, :counts)
  def backup(server, path), do: GenServer.call(server, {:backup, path}, :infinity)
  def operational_health(server), do: GenServer.call(server, :operational_health, :infinity)

  def recent_events(server, limit) when is_integer(limit),
    do: GenServer.call(server, {:recent_events, limit})

  def recent_events(_server, _limit),
    do: {:error, {:invalid_limit, %{minimum: 1, maximum: 1_000}}}

  def checkpoint(server), do: GenServer.call(server, :checkpoint, :infinity)

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)
    path = Keyword.fetch!(opts, :path)

    case PathIdentity.existing(path) do
      {:error, :database_not_found} ->
        {:ok, recovery_state(path, :not_initialized)}

      {:ok, identity} ->
        open(identity, opts)

      {:error, reason} ->
        {:ok, recovery_state(path, reason)}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.operational_health_requests, fn {token, request} ->
      send(request.pid, {:cancel_capacity_probe, token})
    end)

    _ = Database.close(state.conn)
    if state.owner, do: Owner.release(state.owner)
    :ok
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{mode: state.mode, reason: state.reason, path: state.path}, state}
  end

  def handle_call(:operational_health, _from, %{mode: :recovery} = state) do
    {:reply,
     {:error,
      {:recovery_mode, state.reason,
       %{capacity: %{status: :unknown}, last_durable_sequence: :unknown}}}, state}
  end

  def handle_call(:operational_health, from, state) do
    case Maintenance.read_operational_health(state) do
      {:ok, health} ->
        owner = self()
        token = make_ref()

        {pid, monitor} =
          spawn_monitor(fn ->
            Maintenance.capacity_probe_controller(
              owner,
              token,
              state.capacity_probe,
              state.path,
              state.capacity_probe_timeout_ms
            )
          end)

        request = %{
          from: from,
          health: health,
          pid: pid,
          monitor: monitor,
          caller_monitor: Process.monitor(elem(from, 0))
        }

        {:noreply, put_in(state.operational_health_requests[token], request)}

      {:error, _reason} = result ->
        {:reply, result, transition_after_result(state, result)}
    end
  end

  def handle_call({:recent_events, _limit}, _from, %{mode: :recovery} = state) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:recent_events, limit}, _from, state) do
    result = Maintenance.query_recent_events(state.conn, limit)
    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call(:checkpoint, _from, %{mode: :recovery} = state) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call(:checkpoint, _from, state) do
    result = Maintenance.checkpoint_database(state.conn, state.maintenance_fault)
    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call({:transact, _actor_id, _command, _proposal}, _from, %{mode: :recovery} = state) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:transact, actor_id, command, proposal}, _from, state) do
    result = DomainCommit.do_transact(state.conn, actor_id, command, proposal, state.fault)

    next_state = transition_after_result(state, result)

    {:reply, result, next_state}
  end

  def handle_call({:command, _command_id}, _from, %{mode: :recovery} = state) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:command, command_id}, _from, state) do
    result = DomainCommit.fetch_command(state.conn, command_id)
    next = transition_after_result(state, result)
    reply = if next.mode == :recovery, do: {:error, {:recovery_mode, next.reason}}, else: result
    {:reply, reply, next}
  end

  def handle_call(
        {:protected_command, _capability, _actor_id, _request},
        _from,
        %{mode: :recovery} = state
      ) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:protected_command, capability, actor_id, request}, _from, state) do
    result =
      if capability === state.protected_capability do
        case ProtectedPrimitives.authority_mode(state.conn) do
          {:ok, :legacy} ->
            {:error, :legacy_authority_mode_active}

          {:ok, _mode} ->
            ProtectedPrimitives.execute(
              state.conn,
              actor_id,
              request,
              state.writer_epoch,
              state.fault
            )

          {:error, _reason} = error ->
            error
        end
      else
        {:error, :unauthorized_protected_operation}
      end

    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call(
        {:atomic_bundle, _capability, _actor_id, _envelope},
        _from,
        %{mode: :recovery} = state
      ) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:atomic_bundle, capability, actor_id, envelope}, _from, state) do
    result =
      if capability === state.protected_capability do
        case ProtectedPrimitives.authority_mode(state.conn) do
          {:ok, :legacy} ->
            {:error, :legacy_authority_mode_active}

          {:ok, _mode} ->
            do_atomic_bundle(
              state.conn,
              actor_id,
              envelope,
              state.writer_epoch,
              state.fault
            )

          {:error, _reason} = error ->
            error
        end
      else
        {:error, :unauthorized_protected_operation}
      end

    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call(
        {:protected_query, _capability, _query},
        _from,
        %{mode: :recovery} = state
      ) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:protected_query, capability, query}, _from, state) do
    result =
      if capability === state.protected_capability do
        ProtectedPrimitives.query(state.conn, query)
      else
        {:error, :unauthorized_protected_operation}
      end

    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call(
        {:protected_snapshot, _capability},
        _from,
        %{mode: :recovery} = state
      ) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:protected_snapshot, capability}, _from, state) do
    result =
      if capability === state.protected_capability do
        ProtectedPrimitives.snapshot(state.conn, state.writer_epoch)
      else
        {:error, :unauthorized_protected_operation}
      end

    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call(:counts, _from, %{mode: :recovery} = state) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call(:counts, _from, state) do
    tables =
      ~w(inputs commands command_results events projections effects claims ledger_generations reservations)

    result =
      with {:ok, %{content: content}} <- Authority.read(state.conn, :all) do
        {:ok, Map.new(tables, &{&1, content[&1].count})}
      end

    {:reply, result, transition_after_result(state, result)}
  end

  def handle_call({:backup, _path}, _from, %{mode: :recovery} = state) do
    {:reply, {:error, {:recovery_mode, state.reason}}, state}
  end

  def handle_call({:backup, path}, _from, state) do
    result = Maintenance.backup_database(state.conn, path, state.maintenance_fault)
    {:reply, result, transition_after_result(state, result)}
  end

  @impl true
  def handle_info({:operational_health_capacity, token, result}, state) do
    case Map.pop(state.operational_health_requests, token) do
      {nil, _requests} ->
        {:noreply, state}

      {request, requests} ->
        Process.demonitor(request.monitor, [:flush])
        Process.demonitor(request.caller_monitor, [:flush])
        physical = Maintenance.normalize_capacity_result(result)

        GenServer.reply(
          request.from,
          {:ok, Maintenance.add_physical_capacity(request.health, physical)}
        )

        {:noreply, %{state | operational_health_requests: requests}}
    end
  end

  def handle_info({:operational_health_capacity_timeout, token}, state) do
    case Map.pop(state.operational_health_requests, token) do
      {nil, _requests} ->
        {:noreply, state}

      {request, requests} ->
        Process.demonitor(request.monitor, [:flush])
        Process.demonitor(request.caller_monitor, [:flush])

        GenServer.reply(
          request.from,
          {:ok,
           Maintenance.add_physical_capacity(request.health, {:unknown, :capacity_probe_timeout})}
        )

        {:noreply, %{state | operational_health_requests: requests}}
    end
  end

  def handle_info({:DOWN, monitor, :process, pid, reason}, state) do
    case find_health_request(state.operational_health_requests, monitor, pid) do
      nil ->
        {:noreply, state}

      {token, request, :worker} ->
        Process.demonitor(request.caller_monitor, [:flush])

        physical = {:unknown, {:capacity_probe_worker_exit, reason}}

        GenServer.reply(
          request.from,
          {:ok, Maintenance.add_physical_capacity(request.health, physical)}
        )

        {:noreply, update_in(state.operational_health_requests, &Map.delete(&1, token))}

      {token, request, :caller} ->
        send(request.pid, {:cancel_capacity_probe, token})
        Process.demonitor(request.monitor, [:flush])
        {:noreply, update_in(state.operational_health_requests, &Map.delete(&1, token))}
    end
  end

  defp find_health_request(requests, monitor, pid) do
    Enum.find_value(requests, fn {token, request} ->
      cond do
        request.monitor == monitor and request.pid == pid -> {token, request, :worker}
        request.caller_monitor == monitor -> {token, request, :caller}
        true -> nil
      end
    end)
  end

  defp open(identity, opts) do
    path = identity.path

    with {:ok, owner} <- Owner.acquire(identity, opts) do
      open_result =
        with :ok <- PathIdentity.revalidate(owner.identity),
             {:ok, conn} <- Database.open(owner.identity),
             :ok <- PathIdentity.revalidate(owner.identity) do
          {:ok, conn}
        end

      case open_result do
        {:ok, conn} ->
          with :ok <- maybe_limit_pages(conn, Keyword.get(opts, :max_page_count)) do
            {:ok,
             %{
               path: path,
               conn: conn,
               owner: owner,
               mode: :ready,
               reason: nil,
               fault: Keyword.get(opts, :fault),
               maintenance_fault: Keyword.get(opts, :maintenance_fault),
               capacity_probe: Keyword.get(opts, :capacity_probe, &Capacity.probe/1),
               capacity_probe_timeout_ms:
                 Keyword.get(opts, :capacity_probe_timeout_ms, @capacity_probe_timeout_ms),
               operational_health_requests: %{},
               protected_capability:
                 Keyword.get_lazy(opts, :protected_capability, fn -> make_ref() end),
               writer_epoch:
                 Keyword.get_lazy(opts, :writer_epoch, fn ->
                   16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
                 end)
             }}
          else
            {:error, reason} ->
              Database.close(conn)
              Owner.release(owner)

              {:ok, recovery_state(path, reason)}
          end

        {:error, reason} ->
          Owner.release(owner)

          {:ok, recovery_state(path, reason)}
      end
    else
      {:error, reason} ->
        {:ok, recovery_state(path, reason)}
    end
  end

  defp do_atomic_bundle(conn, actor_id, envelope, writer_epoch, fault) do
    with {:ok, normalized, canonical, digest} <- normalize_atomic_envelope(actor_id, envelope) do
      command_id = normalized["command"]["command_id"]

      case existing_atomic_bundle(conn, command_id, actor_id, digest) do
        {:ok, result} ->
          {:ok, result, :idempotent}

        {:error, :not_found} ->
          commit_atomic_bundle(conn, normalized, canonical, digest, writer_epoch, fault)

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp normalize_atomic_envelope(actor_id, envelope) do
    with :ok <- DomainCommit.validate_actor(actor_id),
         {:ok, normalized_input} <- canonical_value(envelope),
         {:ok, carrier} <- atomic_carrier(normalized_input),
         2 <- normalized_input["schema_version"],
         ^actor_id <- normalized_input["actor_id"],
         true <- plain_map?(normalized_input["inputs"]),
         {:ok, command} <- RecordCodec.normalize(:command, normalized_input["command"]),
         {:ok, operations} <- normalize_atomic_operations(normalized_input["operations"]),
         {:ok, carried} <-
           normalize_atomic_carrier(carrier, normalized_input[carrier], operations),
         :ok <- plan_domain_reads_checked(carrier, carried, command),
         normalized <- %{
           "schema_version" => 2,
           "actor_id" => actor_id,
           "inputs" => normalized_input["inputs"],
           "command" => command,
           "operations" => operations,
           carrier => carried
         },
         {:ok, canonical} <- Encoding.canonical(normalized),
         {:ok, digest} <-
           Encoding.semantic_digest("foundry-atomic-bundle-v2", normalized) do
      {:ok, normalized, canonical, digest}
    else
      {:error, _reason} = error -> error
      _ -> {:error, :invalid_atomic_bundle}
    end
  end

  defp normalize_atomic_operations(operations) when is_list(operations) do
    operations
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {entry, ordinal}, {:ok, acc} ->
      with true <- plain_map?(entry),
           true <-
             Map.keys(entry) |> Enum.sort() == ~w(expected_revisions operation schema_version),
           1 <- entry["schema_version"],
           true <- plain_map?(entry["expected_revisions"]),
           true <- plain_map?(entry["operation"]),
           type when is_binary(type) <- entry["operation"]["type"],
           true <- ProtectedPrimitives.supported_operation_type?(type) do
        normalized =
          entry
          |> Map.put("ordinal", ordinal)
          |> Map.put("operation_type", type)

        {:cont, {:ok, [normalized | acc]}}
      else
        _ -> {:halt, {:error, :invalid_atomic_operation}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp normalize_atomic_operations(_operations), do: {:error, :invalid_atomic_operations}

  defp existing_atomic_bundle(conn, command_id, actor_id, digest) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT actor_id, request_digest, result FROM atomic_bundles WHERE command_id = ?",
             [command_id]
           ) do
      case rows do
        [[^actor_id, ^digest, bytes]] ->
          decode_json_map(bytes)

        [[_actor, _digest, _bytes]] ->
          {:error, :idempotency_conflict}

        [] ->
          with {:ok, [[domain_count]]} <-
                 Database.query(conn, "SELECT count(*) FROM commands WHERE command_id = ?", [
                   command_id
                 ]),
               {:ok, [[root_count]]} <-
                 Database.query(conn, "SELECT count(*) FROM root_commands WHERE command_id = ?", [
                   command_id
                 ]) do
            if domain_count == 0 and root_count == 0,
              do: {:error, :not_found},
              else: {:error, :idempotency_conflict}
          end

        _ ->
          {:error, :duplicate_atomic_command}
      end
    end
  end

  defp commit_atomic_bundle(conn, envelope, canonical, digest, writer_epoch, fault) do
    result =
      Database.transaction(conn, fn ->
        with :ok <- validate_atomic_prestate(conn, envelope["operations"]),
             {:ok, staged} <- stage_atomic_operations(conn, envelope, digest, writer_epoch),
             :ok <- DomainCommit.inject(fault, :after_protected) do
          case staged do
            {:quarantined, operation_results, reason} ->
              commit_quarantined_atomic_bundle(
                conn,
                envelope,
                canonical,
                digest,
                operation_results,
                reason,
                fault
              )

            {:accepted, operation_results} ->
              commit_accepted_atomic_bundle(
                conn,
                envelope,
                canonical,
                digest,
                operation_results,
                fault
              )
          end
        else
          {:error, reason} when reason in [:incomplete_read_set, :stale_read_set] ->
            {:error,
             {:atomic_rejection, reason, unexecuted_operation_results(envelope, digest, reason)}}

          {:error, _reason} = error ->
            error
        end
      end)

    case result do
      {:ok, {:accepted, durable}} ->
        atomic_reply(envelope, durable, :committed, fault)

      {:ok, {:quarantined, durable}} ->
        atomic_reply(envelope, durable, :quarantined, fault)

      {:error, {:atomic_rejection, reason, operation_results}} ->
        persist_atomic_rejection(
          conn,
          envelope,
          canonical,
          digest,
          reason,
          operation_results,
          fault
        )

      {:error, reason} ->
        {:error, {:storage_unavailable, reason}}
    end
  end

  defp stage_atomic_operations(conn, envelope, digest, writer_epoch) do
    operations = envelope["operations"]

    operations
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      ordinal = entry["ordinal"]

      with {:ok, staged_reads} <- ProtectedPrimitives.required_revisions(conn, entry["operation"]) do
        request = %{
          "schema_version" => 1,
          "command_id" => atomic_operation_id(digest, ordinal),
          "expected_revisions" => staged_reads,
          "operation" => entry["operation"]
        }

        case ProtectedPrimitives.execute_in_transaction(
               conn,
               envelope["actor_id"],
               request,
               writer_epoch
             ) do
          {:ok, result, status} when status in [:accepted, :idempotent] ->
            with true <- result["disposition"] == "accepted",
                 {:ok, result, settlement_status} <-
                   maybe_persist_nonstart(conn, entry["operation"], result) do
              item = atomic_operation_result(entry, request, result, "committed")

              if settlement_status == :duplicate do
                rejected =
                  duplicate_operation_results(envelope, digest, item, acc)

                {:halt, {:error, {:atomic_rejection, :duplicate_receipt, rejected}}}
              else
                {:cont, {:ok, [item | acc]}}
              end
            else
              false ->
                rejected =
                  rejected_operation_results(
                    envelope,
                    digest,
                    acc,
                    :cached_rejected_operation
                  )

                {:halt, {:error, {:atomic_rejection, :cached_rejected_operation, rejected}}}

              {:error, reason} ->
                item = atomic_operation_result(entry, request, result, "rolled_back")
                rejected = rejected_operation_results(envelope, digest, [item | acc], reason)
                {:halt, {:error, {:atomic_rejection, reason, rejected}}}
            end

          {:ok, result, :rejected} ->
            item = atomic_operation_result(entry, request, result, "rolled_back")
            reason = result["reason_code"] || "protected_rejection"
            rejected = rejected_operation_results(envelope, digest, [item | acc], reason)
            {:halt, {:error, {:atomic_rejection, reason, rejected}}}

          {:ok, result, :quarantined} when ordinal == 0 and length(operations) == 1 ->
            item = atomic_operation_result(entry, request, result, "committed")

            {:halt,
             {:ok,
              {:quarantined, Enum.reverse([item | acc]),
               result["reason_code"] || "protected_quarantine"}}}

          {:ok, result, :quarantined} ->
            item = atomic_operation_result(entry, request, result, "rolled_back")

            rejected =
              rejected_operation_results(
                envelope,
                digest,
                [item | acc],
                "quarantine_requires_single_operation"
              )

            {:halt,
             {:error, {:atomic_rejection, "quarantine_requires_single_operation", rejected}}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, {:quarantined, _results, _reason} = value} -> {:ok, value}
      {:ok, results} when is_list(results) -> {:ok, {:accepted, Enum.reverse(results)}}
      error -> error
    end
  end

  defp validate_atomic_prestate(conn, operations) do
    operations
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, prior} ->
      with {:ok, required} <-
             ProtectedPrimitives.required_bundle_prestate_revisions(
               conn,
               entry["operation"],
               Enum.reverse(prior)
             ) do
        supplied = entry["expected_revisions"]

        cond do
          required == supplied ->
            {:cont, {:ok, [entry["operation"] | prior]}}

          Enum.sort(Map.keys(required)) == Enum.sort(Map.keys(supplied)) ->
            {:halt, {:error, :stale_read_set}}

          true ->
            {:halt, {:error, :incomplete_read_set}}
        end
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, _prior} -> :ok
      error -> error
    end
  end

  defp unexecuted_operation_results(envelope, digest, reason),
    do: rejected_operation_results(envelope, digest, [], reason)

  defp rejected_operation_results(envelope, digest, executed, reason) do
    executed =
      executed
      |> Enum.map(&rolled_back_operation_result(&1, reason))
      |> Map.new(&{&1["ordinal"], &1})

    Enum.map(envelope["operations"], fn entry ->
      Map.get_lazy(executed, entry["ordinal"], fn ->
        request = %{
          "schema_version" => 1,
          "command_id" => atomic_operation_id(digest, entry["ordinal"]),
          "expected_revisions" => entry["expected_revisions"],
          "operation" => entry["operation"]
        }

        atomic_operation_result(
          entry,
          request,
          %{
            "schema_version" => 1,
            "command_id" => request["command_id"],
            "disposition" => "unexecuted",
            "reason_code" => atomic_reason(reason),
            "facts" => %{}
          },
          "unexecuted"
        )
      end)
    end)
  end

  defp rolled_back_operation_result(item, reason) do
    result = %{
      "schema_version" => 1,
      "command_id" => get_in(item, ["request", "command_id"]),
      "disposition" => "rolled_back",
      "reason_code" => atomic_reason(reason),
      "facts" => %{}
    }

    item
    |> Map.put("execution_status", "rolled_back")
    |> Map.put("result", result)
  end

  defp duplicate_operation_results(envelope, digest, duplicate, earlier) do
    settlement = get_in(duplicate, ["result", "facts", "infrastructure_settlement"])

    duplicate = %{
      duplicate
      | "execution_status" => "duplicate",
        "result" => %{
          "schema_version" => 1,
          "command_id" => get_in(duplicate, ["request", "command_id"]),
          "disposition" => "duplicate",
          "reason_code" => "duplicate_receipt",
          "facts" => %{"infrastructure_settlement" => settlement}
        }
    }

    rejected_operation_results(envelope, digest, earlier, :duplicate_receipt)
    |> List.replace_at(duplicate["ordinal"], duplicate)
  end

  defp maybe_persist_nonstart(
         conn,
         %{"type" => "settle_claim", "outcome" => "non_started"} = op,
         result
       ) do
    with {:ok, settlement} <-
           ProtectedPrimitives.persist_nonstart_settlement(conn, op, result["facts"]) do
      status = if settlement["duplicate"] == true, do: :duplicate, else: :new
      settlement = Map.delete(settlement, "duplicate")
      {:ok, put_in(result, ["facts", "infrastructure_settlement"], settlement), status}
    end
  end

  defp maybe_persist_nonstart(_conn, _operation, result), do: {:ok, result, :none}

  defp atomic_operation_result(entry, request, result, execution_status) do
    %{
      "ordinal" => entry["ordinal"],
      "operation_kind" => "protected",
      "operation_type" => entry["operation_type"],
      "execution_status" => execution_status,
      "request" => request,
      "result" => result
    }
  end

  defp atomic_operation_id(digest, ordinal), do: "atomic-v2/#{digest}/#{ordinal}"

  defp commit_accepted_atomic_bundle(
         conn,
         envelope,
         canonical,
         digest,
         operation_results,
         fault
       ) do
    actor_id = envelope["actor_id"]
    command = envelope["command"]
    {domain_canonical, domain_digest} = prepare_command!(actor_id, command)

    with {:ok, proposal, discriminator} <-
           atomic_domain_proposal(conn, envelope, operation_results),
         :ok <- DomainCommit.check_expected_revisions(conn, command, proposal),
         {:ok, {:accepted, domain_result}} <-
           DomainCommit.commit_accepted_bundle(
             conn,
             actor_id,
             command,
             domain_canonical,
             domain_digest,
             proposal,
             nil,
             :bundle_v2
           ),
         :ok <- DomainCommit.inject(fault, :after_domain),
         durable <-
           atomic_result(
             command["command_id"],
             "accepted",
             nil,
             operation_results,
             domain_result,
             discriminator
           ),
         :ok <-
           persist_atomic_records(
             conn,
             envelope,
             canonical,
             digest,
             durable,
             operation_results,
             domain_result
           ),
         {:ok, _checked} <- Authority.read(conn, :all),
         :ok <- DomainCommit.inject(fault, :before_commit) do
      {:ok, {:accepted, durable}}
    else
      {:error, reason}
      when reason in [:incomplete_expected_revisions, :projection_read_mismatch] ->
        {:error,
         {:atomic_rejection, reason,
          rejected_operation_results(envelope, digest, operation_results, reason)}}

      {:error, {:revision_conflict, _key, _expected, _actual} = reason} ->
        {:error,
         {:atomic_rejection, reason,
          rejected_operation_results(envelope, digest, operation_results, reason)}}

      {:error, {:plan_rejected, reason}} ->
        {:error,
         {:atomic_rejection, reason,
          rejected_operation_results(envelope, digest, operation_results, reason)}}

      {:error, _reason} = error ->
        error
    end
  end

  defp commit_quarantined_atomic_bundle(
         conn,
         envelope,
         canonical,
         digest,
         operation_results,
         reason,
         fault
       ) do
    actor_id = envelope["actor_id"]
    command = envelope["command"]
    {domain_canonical, domain_digest} = prepare_command!(actor_id, command)
    reason_code = atomic_reason(reason)

    with {:ok, {:rejected, domain_result}} <-
           DomainCommit.commit_rejected_command(
             conn,
             actor_id,
             command,
             domain_canonical,
             domain_digest,
             {:atomic, reason_code},
             :bundle_v2
           ),
         durable <-
           atomic_result(
             command["command_id"],
             "quarantined",
             reason_code,
             operation_results,
             domain_result
           ),
         :ok <-
           persist_atomic_records(
             conn,
             envelope,
             canonical,
             digest,
             durable,
             operation_results,
             domain_result
           ),
         {:ok, _checked} <- Authority.read(conn, :all),
         :ok <- DomainCommit.inject(fault, :before_commit) do
      {:ok, {:quarantined, durable}}
    end
  end

  defp persist_atomic_rejection(
         conn,
         envelope,
         canonical,
         digest,
         reason,
         operation_results,
         fault
       ) do
    actor_id = envelope["actor_id"]
    command = envelope["command"]
    {domain_canonical, domain_digest} = prepare_command!(actor_id, command)
    reason_code = atomic_reason(reason)

    transaction_result =
      Database.transaction(conn, fn ->
        with {:ok, {:rejected, domain_result}} <-
               DomainCommit.commit_rejected_command(
                 conn,
                 actor_id,
                 command,
                 domain_canonical,
                 domain_digest,
                 {:atomic, reason_code},
                 :bundle_v2
               ),
             durable <-
               atomic_result(
                 command["command_id"],
                 "rejected",
                 reason_code,
                 operation_results,
                 domain_result
               ),
             :ok <-
               persist_atomic_records(
                 conn,
                 envelope,
                 canonical,
                 digest,
                 durable,
                 operation_results,
                 domain_result
               ),
             {:ok, _checked} <- Authority.read(conn, :all),
             :ok <- DomainCommit.inject(fault, :before_commit) do
          {:ok, durable}
        end
      end)

    case transaction_result do
      {:ok, durable} -> atomic_reply(envelope, durable, :rejected, fault)
      {:error, why} -> {:error, {:storage_unavailable, why}}
    end
  end

  defp persist_atomic_records(
         conn,
         envelope,
         canonical,
         digest,
         durable,
         operation_results,
         domain_result
       ) do
    command_id = envelope["command"]["command_id"]

    with {:ok, result_bytes} <- Encoding.json(durable),
         :ok <-
           Database.execute(
             conn,
             "INSERT INTO atomic_bundles(command_id, actor_id, request_digest, schema_version, disposition, reason_code, canonical_envelope, result) VALUES (?, ?, ?, 2, ?, ?, ?, ?)",
             [
               command_id,
               envelope["actor_id"],
               digest,
               durable["disposition"],
               durable["reason_code"],
               {:blob, canonical},
               {:blob, result_bytes}
             ]
           ),
         :ok <- persist_atomic_operation_rows(conn, command_id, operation_results),
         domain_entry <- %{
           "ordinal" => length(operation_results),
           "operation_kind" => "domain",
           "operation_type" => envelope["command"]["type"],
           "execution_status" =>
             if(durable["disposition"] == "accepted", do: "committed", else: "rejected"),
           # Keyed by the envelope's real carrier. Previously this always wrote
           # "proposal", which is nil for a plan-bearing envelope — recording that no
           # proposal existed for a bundle that had just committed one. A
           # proposal-bearing row is byte-identical to before, so stored histories and
           # the protected domain-row validator are unaffected.
           "request" => atomic_domain_request(envelope),
           "result" => domain_result
         },
         :ok <- persist_atomic_operation_rows(conn, command_id, [domain_entry]) do
      :ok
    end
  end

  defp persist_atomic_operation_rows(conn, command_id, entries) do
    Enum.reduce_while(entries, :ok, fn entry, :ok ->
      with {:ok, request_bytes} <- Encoding.json(entry["request"]),
           {:ok, result_bytes} <-
             Encoding.json(%{
               "schema_version" => 1,
               "execution_status" => entry["execution_status"],
               "operation_result" => entry["result"]
             }),
           :ok <-
             Database.execute(
               conn,
               "INSERT INTO durable_operations(owner_kind, owner_id, ordinal, operation_kind, operation_type, request, result) VALUES ('bundle_v2', ?, ?, ?, ?, ?, ?)",
               [
                 command_id,
                 entry["ordinal"],
                 entry["operation_kind"],
                 entry["operation_type"],
                 {:blob, request_bytes},
                 {:blob, result_bytes}
               ]
             ) do
        {:cont, :ok}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp atomic_result(command_id, disposition, reason, operation_results, domain_result),
    do: atomic_result(command_id, disposition, reason, operation_results, domain_result, nil)

  # The selected discriminator is recorded so a reader need not recompute it. Revalidation
  # does recompute it, from the policy at the effect's own revision, and must agree.
  defp atomic_result(
         command_id,
         disposition,
         reason,
         operation_results,
         domain_result,
         discriminator
       ) do
    %{
      "schema_version" => 2,
      "command_id" => command_id,
      "disposition" => disposition,
      "reason_code" => reason,
      "committed_seq" => domain_result["committed_seq"],
      "operations" =>
        Enum.map(operation_results, fn item ->
          Map.take(item, ~w(ordinal operation_kind operation_type execution_status result))
        end),
      "domain_result" => domain_result,
      "selected_discriminator" => discriminator
    }
  end

  defp prepare_command!(actor_id, command) do
    case DomainCommit.prepare_command(actor_id, command) do
      {:ok, canonical, digest, _normalized} -> {canonical, digest}
    end
  end

  defp atomic_reply(envelope, _durable, _status, :after_commit_before_reply),
    do: {:error, {:outcome_unknown, envelope["command"]["command_id"]}}

  defp atomic_reply(_envelope, durable, status, _fault), do: {:ok, durable, status}

  defp atomic_reason({:revision_conflict, _key, _expected, _actual}), do: "revision_conflict"
  defp atomic_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp atomic_reason(reason) when is_binary(reason) and reason != "", do: reason
  defp atomic_reason(_reason), do: "atomic_bundle_rejected"

  defp canonical_value(value) do
    with {:ok, bytes} <- Encoding.json(value), do: decode_json_map(bytes)
  end

  defp decode_json_map(bytes) when is_binary(bytes) do
    try do
      case :json.decode(bytes) do
        value when is_map(value) -> {:ok, normalize_json(value)}
        _ -> {:error, :invalid_json_map}
      end
    rescue
      _ -> {:error, :invalid_json_map}
    end
  end

  defp normalize_json(:null), do: nil
  defp normalize_json(value) when is_list(value), do: Enum.map(value, &normalize_json/1)

  defp normalize_json(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, normalize_json(item)} end)

  defp normalize_json(value), do: value

  defp plain_map?(value), do: is_map(value) and not is_struct(value)

  # A v2 envelope carries either a precomputed proposal or an unresolved transition plan,
  # never both and never neither. The digest is computed over whichever it carries, so a
  # plan-bearing command digests over its *unresolved* plan: the same command must digest
  # identically regardless of which alternative the protected discriminator later selects,
  # or an idempotent retry after a lost reply could not find its original result.
  # A proposal-bearing envelope commits what it carried. A plan-bearing one is resolved
  # here: the protected layer derives the discriminator from facts staged inside this same
  # transaction, and the codec mechanically selects and substitutes. Gateway never
  # executes candidate code to decide what commits, and never accepts a caller's copy of
  # an authoritative fact — bind/3 takes the staged results, not a supplied map.
  defp atomic_domain_proposal(_conn, %{"proposal" => proposal}, _results),
    do: {:ok, proposal, nil}

  defp atomic_domain_proposal(conn, %{"plan" => plan}, results) do
    with {:ok, discriminator} <- protected_discriminator(conn, plan, results),
         {:ok, proposal} <- TransitionPlan.bind(plan, discriminator, results) do
      {:ok, proposal, discriminator}
    else
      # Tagged so a rejected plan can never be mistaken for an infrastructure fault.
      # Untagged, these errors reached the generic catch-all, were mapped to
      # :storage_unavailable, and flipped the whole Gateway into permanent recovery mode
      # for every actor. A candidate-authored plan being wrong is an ordinary rejection.
      # The tag also means this does not have to enumerate TransitionPlan's error
      # vocabulary, and cannot accidentally swallow a genuine storage failure.
      {:error, reason} -> {:error, {:plan_rejected, reason}}
    end
  end

  # The kind is a closed vocabulary validated by TransitionPlan, so this maps a name to
  # one fixed protected function rather than dispatching on caller-supplied text.
  defp protected_discriminator(
         conn,
         %{"discriminator_kind" => "infrastructure_limit_v1"} = plan,
         results
       ) do
    with {:ok, settlement} <- staged_settlement_fact(plan, results) do
      ProtectedPrimitives.infrastructure_discriminator_at_revision(
        conn,
        settlement["effect_id"],
        settlement
      )
    end
  end

  defp protected_discriminator(_conn, %{"discriminator_kind" => "unconditional_v1"}, _results),
    do: {:ok, "unconditional"}

  defp protected_discriminator(_conn, _plan, _results),
    do: {:error, :unsupported_discriminator_kind}

  # Resolved through the ordinal the plan's settlement binding declares, not by scanning
  # every staged result for a unique settlement. The scanning form failed closed, but it
  # would have refused a legitimate bundle settling two independent role launches
  # atomically, and it let the discriminator describe a settlement the plan never bound.
  defp staged_settlement_fact(plan, results) do
    case Enum.filter(plan["bindings"], &(&1["output_kind"] == "nonstart_settlement_v1")) do
      [binding] ->
        settlement =
          results
          |> Enum.find(%{}, &(&1["ordinal"] == binding["operation_ordinal"]))
          |> get_in(["result", "facts", "infrastructure_settlement"])

        if is_map(settlement),
          do: {:ok, settlement},
          else: {:error, :discriminator_settlement_unavailable}

      _ ->
        {:error, :discriminator_settlement_unavailable}
    end
  end

  defp atomic_carrier(input) do
    case Enum.sort(Map.keys(input)) do
      ~w(actor_id command inputs operations proposal schema_version) -> {:ok, "proposal"}
      ~w(actor_id command inputs operations plan schema_version) -> {:ok, "plan"}
      _ -> {:error, :invalid_atomic_bundle}
    end
  end

  defp atomic_carrier_name(%{"plan" => _}), do: "plan"
  defp atomic_carrier_name(_envelope), do: "proposal"

  @doc false
  # Public to the protected validator, which must reconstruct exactly this shape.
  def atomic_domain_request(envelope) do
    carrier = atomic_carrier_name(envelope)

    %{
      "command" => envelope["command"],
      "inputs" => envelope["inputs"],
      carrier => envelope[carrier]
    }
  end

  defp normalize_atomic_carrier("proposal", value, _operations),
    do: DomainCommit.normalize_candidate(value)

  defp normalize_atomic_carrier("plan", value, operations) do
    with {:ok, plan} <- TransitionPlan.validate(value),
         :ok <- plan_describes_operations(plan, operations) do
      {:ok, plan}
    end
  end

  # A plan whose declared operations disagree with the ones the envelope actually stages
  # is incoherent. derive_output/2 validates against the real staged result, so this was
  # not unsound, but an incoherent plan should be refused here rather than tolerated
  # because a later check happens to catch the consequence.
  defp plan_describes_operations(plan, operations) do
    declared =
      Enum.map(plan["protected_operations"], &{&1["ordinal"], &1["type"]})

    staged =
      operations
      |> Enum.with_index()
      |> Enum.map(fn {entry, index} -> {index, entry["operation"]["type"]} end)

    cond do
      declared != staged -> {:error, :plan_operations_mismatch}
      not nonstarts_bound?(plan, operations) -> {:error, :nonstart_settlement_unbound}
      true -> :ok
    end
  end

  # A staged non-start produces a settlement whose branch only Core may derive. Unbound, the
  # plan could pick the branch itself under unconditional_v1 and record no settlement at all
  # (Fable review of the core_boundary F1 fix). The outcome is in the staged operation, not
  # the plan, so this is checked here rather than in TransitionPlan.validate/1.
  defp nonstarts_bound?(plan, operations) do
    bound =
      for binding <- plan["bindings"],
          binding["output_kind"] == "nonstart_settlement_v1",
          do: binding["operation_ordinal"]

    operations
    |> Enum.with_index()
    |> Enum.all?(fn {entry, index} ->
      entry["operation"]["type"] != "settle_claim" or
        entry["operation"]["outcome"] != "non_started" or index in bound
    end)
  end

  # One fixed namespace per domain read kind; `state` is the global singleton `control`.
  # Kernel.Plan keeps the candidate-side copy and a test asserts the two agree. `pm` has
  # no namespace yet, so a plan declaring a pm read is refused as unchecked.
  @domain_read_namespaces %{
    "ticket" => "foundry.ticket.v1",
    "objective" => "foundry.objective.v1",
    "state" => "foundry.state.v1"
  }

  @doc false
  def domain_read_namespaces, do: @domain_read_namespaces

  defp plan_domain_reads_checked("plan", plan, command) do
    written = plan_written_entities(plan)
    expected = command["expected_revisions"]

    checked =
      Enum.map(plan["domain_reads"], fn read ->
        namespace = @domain_read_namespaces[read["kind"]]
        {namespace, read, {namespace, read["entity_id"]} in written}
      end)

    cond do
      not Enum.all?(checked, fn {namespace, read, written?} ->
        is_binary(namespace) and
            Map.fetch(expected, domain_read_key(namespace, read["entity_id"], written?)) ==
              {:ok, read["revision"]}
      end) ->
        {:error, :domain_read_not_checked}

      plan["expected_domain_revision"] != expected_domain_revision(checked) ->
        {:error, :expected_domain_revision_mismatch}

      true ->
        :ok
    end
  end

  defp plan_domain_reads_checked(_carrier, _carried, _command), do: :ok

  # The kernel revision of the entity the projections write: durable revision + 1, with
  # absent as 0. A plan that writes no declared read targets revision 0.
  defp expected_domain_revision(checked) do
    case for({_namespace, read, true} <- checked, do: read["revision"]) do
      [] -> 0
      ["absent"] -> 0
      [revision] -> revision + 1
      _several -> :ambiguous
    end
  end

  defp plan_written_entities(plan) do
    for %{"proposal" => %{"projections" => projections}} <- plan["alternatives"],
        is_list(projections),
        %{"namespace" => namespace, "entity_id" => entity_id} <- projections,
        into: MapSet.new(),
        do: {namespace, entity_id}
  end

  defp domain_read_key(namespace, entity_id, true),
    do: DomainCommit.projection_key(namespace, entity_id)

  defp domain_read_key(namespace, entity_id, false),
    do:
      "dependency/" <>
        DomainCommit.encode_key(namespace) <> "/" <> DomainCommit.encode_key(entity_id)

  defp transition_after_result(state, result) do
    case result do
      {:error, {:storage_unavailable, _reason}} ->
        %{state | mode: :recovery, reason: result}

      {:error, {:authority_corrupt, _type, _identity, _reason} = reason} ->
        %{state | mode: :recovery, reason: reason}

      _other ->
        state
    end
  end

  defp maybe_limit_pages(_conn, nil), do: :ok

  defp maybe_limit_pages(conn, pages) when is_integer(pages) and pages > 0 do
    with {:ok, [[current]]} <- Database.query(conn, "PRAGMA page_count") do
      # A schema migration can legitimately make an existing absolute fixture limit
      # smaller than the already committed database.  In that case retain the same
      # bounded-growth fault probe by treating the requested pages as additional room.
      target = if pages <= current, do: current + pages, else: pages

      case Database.query(conn, "PRAGMA max_page_count = #{target}") do
        {:ok, [[actual]]} when actual <= target -> :ok
        {:ok, rows} -> {:error, {:page_limit_failed, rows}}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_limit_pages(_conn, _pages), do: {:error, :invalid_page_limit}

  defp recovery_state(path, reason) do
    %{
      path: path,
      conn: nil,
      owner: nil,
      mode: :recovery,
      reason: reason,
      fault: nil,
      maintenance_fault: nil,
      capacity_probe: &Capacity.probe/1,
      capacity_probe_timeout_ms: @capacity_probe_timeout_ms,
      operational_health_requests: %{}
    }
  end
end
