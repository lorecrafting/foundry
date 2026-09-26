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
    AtomicBundle,
    DomainCommit,
    Maintenance,
    Owner,
    PathIdentity,
    ProtectedPrimitives
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
            AtomicBundle.do_atomic_bundle(
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

  @doc false
  defdelegate atomic_domain_request(envelope), to: AtomicBundle

  @doc false
  defdelegate domain_read_namespaces(), to: AtomicBundle

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
