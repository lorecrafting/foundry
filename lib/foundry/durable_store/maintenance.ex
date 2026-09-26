defmodule Foundry.DurableStore.Maintenance do
  @moduledoc """
  Offline verification for a durable-store database or published backup.

  This operation acquires the same OS-process owner as the live gateway. It therefore
  refuses to inspect a database with a live owner and never repairs, replaces or removes
  authority. The returned replay digest is diagnostic evidence, not a second authority.
  """

  alias Foundry.DurableStore.{Authority, Database, Encoding, Owner, PathIdentity}

  @spec verify(Path.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def verify(path, opts \\ []) do
    with {:ok, identity} <- PathIdentity.existing(path),
         {:ok, owner} <- Owner.acquire(identity, opts) do
      result =
        with :ok <- PathIdentity.revalidate(owner.identity),
             {:ok, conn} <- Database.open(owner.identity) do
          try do
            with {:ok, view} <- Authority.read(conn, :all),
                 {:ok, last_seq} <- last_sequence(conn) do
              {:ok,
               %{
                 path: path,
                 last_durable_sequence: last_seq,
                 content: view.content,
                 replay: replay_evidence(view.reconstructed)
               }}
            end
          after
            _ = Database.close(conn)
          end
        end

      case {result, Owner.release(owner)} do
        {result, :ok} -> result
        {_result, {:error, reason}} -> {:error, {:maintenance_owner_release_failed, reason}}
      end
    end
  end

  defp last_sequence(conn) do
    case sequence_query(conn) do
      {:ok, [[sequence]]} -> {:ok, sequence}
      {:error, reason} -> {:error, {:storage_unavailable, reason}}
    end
  end

  defp sequence_query(conn), do: Database.query(conn, "SELECT coalesce(max(seq), 0) FROM events")

  defp replay_evidence(state) do
    %{
      projection_count: map_size(state),
      sha256: state |> :erlang.term_to_binary([:deterministic]) |> Encoding.digest(),
      state: state
    }
  end

  @doc false
  def read_operational_health(state) do
    with {:ok, [[page_count]]} <- Database.query(state.conn, "PRAGMA page_count"),
         {:ok, [[page_size]]} <- Database.query(state.conn, "PRAGMA page_size"),
         {:ok, [[max_page_count]]} <- Database.query(state.conn, "PRAGMA max_page_count"),
         {:ok, [[last_sequence]]} <-
           sequence_query(state.conn) do
      {:ok,
       %{
         mode: :ready,
         last_durable_sequence: last_sequence,
         database_bytes: page_count * page_size,
         wal_bytes: file_size(state.path <> "-wal"),
         capacity: %{
           sqlite_page_count: page_count,
           sqlite_max_page_count: max_page_count,
           sqlite_available_bytes: max(max_page_count - page_count, 0) * page_size
         }
       }}
    else
      {:error, reason} -> {:error, {:storage_unavailable, reason}}
      other -> {:error, {:storage_unavailable, {:invalid_health_result, other}}}
    end
  end

  @doc false
  def add_physical_capacity(health, physical) do
    capacity =
      Map.merge(health.capacity, %{
        physical_available_bytes: physical,
        status: if(is_integer(physical), do: :known, else: :unknown)
      })

    %{health | capacity: capacity}
  end

  @doc false
  def query_recent_events(_conn, limit) when limit < 1 or limit > 1_000,
    do: {:error, {:invalid_limit, %{minimum: 1, maximum: 1_000}}}

  @doc false
  def query_recent_events(conn, limit) do
    case Database.query(
           conn,
           "SELECT seq, event_id, command_id, event_type FROM events ORDER BY seq DESC LIMIT ?",
           [limit]
         ) do
      {:ok, rows} ->
        {:ok,
         Enum.map(rows, fn [sequence, event_id, command_id, event_type] ->
           %{
             sequence: sequence,
             event_id: event_id,
             command_id: command_id,
             event_type: event_type
           }
         end)}

      {:error, reason} ->
        {:error, {:storage_unavailable, reason}}
    end
  end

  @doc false
  def checkpoint_database(conn, fault) do
    with {:ok, before_view} <- Authority.read(conn, :all),
         :ok <- inject_maintenance(fault, :before_checkpoint),
         {:ok, [[busy, log_frames, checkpointed_frames]]} <-
           run_maintenance_operation(fault, :during_checkpoint, conn, fn ->
             Database.query(conn, "PRAGMA wal_checkpoint(TRUNCATE)")
           end),
         true <- busy == 0,
         :ok <- inject_maintenance(fault, :after_checkpoint),
         {:ok, after_view} <- Authority.read(conn, :all),
         true <- before_view.content == after_view.content,
         true <- before_view.reconstructed == after_view.reconstructed,
         {:ok, [[last_sequence]]} <-
           sequence_query(conn) do
      {:ok,
       %{
         busy: busy,
         log_frames: log_frames,
         checkpointed_frames: checkpointed_frames,
         last_durable_sequence: last_sequence
       }}
    else
      false -> {:error, {:authority_corrupt, "sqlite", "checkpoint", :content_mismatch}}
      {:error, {:authority_corrupt, _table, _identity, _reason} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:storage_unavailable, reason}}
      other -> {:error, {:storage_unavailable, {:checkpoint_failed, other}}}
    end
  end

  defp inject_maintenance({:halt, point}, point), do: System.halt(74)
  defp inject_maintenance({:error, point}, point), do: {:error, {:injected_maintenance, point}}
  defp inject_maintenance(_fault, _point), do: :ok

  defp start_maintenance_fault({:during, point, fun}, point, conn) when is_function(fun, 1),
    do: fun.(conn)

  defp start_maintenance_fault(_fault, _point, _conn), do: :ok

  defp run_maintenance_operation(fault, point, conn, operation) do
    case start_maintenance_fault(fault, point, conn) do
      {:scoped, finish} when is_function(finish, 1) ->
        try do
          result = operation.()

          case finish.(result) do
            :ok -> result
            {:error, _reason} = error -> error
            other -> {:error, {:maintenance_fault_cleanup_failed, other}}
          end
        catch
          kind, reason ->
            stacktrace = __STACKTRACE__
            _ = finish.({:raised, kind, reason})
            :erlang.raise(kind, reason, stacktrace)
        end

      :ok ->
        operation.()

      {:error, _reason} = error ->
        error

      other ->
        {:error, {:invalid_maintenance_fault_result, other}}
    end
  end

  @doc false
  def capacity_probe_controller(owner, token, probe, path, timeout_ms) do
    owner_monitor = Process.monitor(owner)
    controller = self()

    {probe_pid, probe_monitor} =
      spawn_monitor(fn ->
        result = invoke_capacity_probe(probe, path)
        send(controller, {:capacity_probe_result, self(), result})
      end)

    timer = Process.send_after(controller, :capacity_probe_timeout, timeout_ms)

    await_capacity_probe(
      owner,
      owner_monitor,
      token,
      probe_pid,
      probe_monitor,
      timer
    )
  end

  defp await_capacity_probe(owner, owner_monitor, token, probe_pid, probe_monitor, timer) do
    receive do
      {:capacity_probe_result, ^probe_pid, result} ->
        Process.cancel_timer(timer)
        Process.demonitor(probe_monitor, [:flush])
        Process.demonitor(owner_monitor, [:flush])
        send(owner, {:operational_health_capacity, token, result})

      :capacity_probe_timeout ->
        stop_capacity_probe(probe_pid, probe_monitor)
        Process.demonitor(owner_monitor, [:flush])
        send(owner, {:operational_health_capacity_timeout, token})

      {:cancel_capacity_probe, ^token} ->
        Process.cancel_timer(timer)
        stop_capacity_probe(probe_pid, probe_monitor)
        Process.demonitor(owner_monitor, [:flush])

      {:DOWN, ^owner_monitor, :process, ^owner, _reason} ->
        Process.cancel_timer(timer)
        stop_capacity_probe(probe_pid, probe_monitor)

      {:DOWN, ^probe_monitor, :process, ^probe_pid, reason} ->
        Process.cancel_timer(timer)
        Process.demonitor(owner_monitor, [:flush])

        send(
          owner,
          {:operational_health_capacity, token, {:error, {:capacity_probe_worker_exit, reason}}}
        )
    end
  end

  defp stop_capacity_probe(probe_pid, probe_monitor) do
    Process.exit(probe_pid, :kill)

    receive do
      {:DOWN, ^probe_monitor, :process, ^probe_pid, _reason} -> :ok
    end
  end

  defp invoke_capacity_probe(probe, path) do
    probe.(path)
  rescue
    error -> {:error, {:capacity_probe_exception, error}}
  catch
    :exit, reason -> {:error, {:capacity_probe_exit, reason}}
  end

  @doc false
  def normalize_capacity_result(result) do
    case result do
      {:ok, bytes} when is_integer(bytes) and bytes >= 0 -> bytes
      {:error, reason} -> {:unknown, reason}
      other -> {:unknown, {:invalid_capacity_result, other}}
    end
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, stat} -> stat.size
      {:error, :enoent} -> 0
      {:error, reason} -> {:unknown, reason}
    end
  end

  @doc false
  def backup_database(conn, path, fault) do
    with {:ok, source_view} <- Authority.read(conn, :all),
         {:ok, target} <- PathIdentity.new(path),
         {:ok, database_rows} <- Database.query(conn, "PRAGMA database_list"),
         source_path when is_binary(source_path) and source_path != "" <-
           Enum.find_value(database_rows, fn
             [_seq, "main", value] -> value
             _row -> nil
           end),
         {:ok, source} <- PathIdentity.existing(source_path),
         :ok <- PathIdentity.validate_new_database(target),
         :ok <- PathIdentity.validate_publication(source, [target]),
         false <- PathIdentity.collision?(source, target) do
      perform_backup(conn, target, source_view, fault)
    else
      {:error, :target_exists} -> {:error, :backup_exists}
      true -> {:error, :backup_path_collision}
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_backup(conn, target, source_view, fault) do
    escaped = String.replace(target.path, "'", "''")

    with :ok <-
           run_maintenance_operation(fault, :during_backup, conn, fn ->
             Database.execute(conn, "VACUUM INTO '#{escaped}'")
           end),
         :ok <- maybe_interrupt_backup(fault),
         {:ok, snapshot} <- PathIdentity.existing(target.path),
         {:ok, result} <- verify_backup(snapshot, source_view, fault) do
      {:ok, result}
    else
      {:error, {:storage_unavailable, _reason} = reason} -> {:error, reason}
      {:error, reason} -> {:error, {:storage_unavailable, {:backup_failed, reason}}}
      other -> {:error, {:storage_unavailable, {:backup_failed, other}}}
    end
  end

  defp maybe_interrupt_backup(fault), do: inject_maintenance(fault, :after_backup_snapshot)

  defp verify_backup(snapshot, source_view, fault) do
    path = snapshot.path

    open_result =
      with :ok <- PathIdentity.revalidate(snapshot),
           {:ok, conn} <- Database.open(snapshot),
           :ok <- PathIdentity.revalidate(snapshot) do
        {:ok, conn}
      end

    case open_result do
      {:ok, backup} ->
        result =
          with {:ok, backup_view} <- Authority.read(backup, :all),
               true <- source_view.content == backup_view.content,
               true <- source_view.reconstructed == backup_view.reconstructed,
               :ok <- sync_snapshot(path, fault) do
            {:ok,
             %{
               path: path,
               content: backup_view.content,
               reconstruction: replay_evidence(backup_view.reconstructed)
             }}
          else
            false -> {:error, :backup_content_mismatch}
            {:error, reason} -> {:error, reason}
          end

        _ = Database.close(backup)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sync_snapshot(path, fault) do
    with :ok <- sync_file(path, fault),
         :ok <- sync_directory(Path.dirname(path)) do
      :ok
    end
  end

  defp sync_file(path, fault) do
    case :file.open(String.to_charlist(path), [:read, :binary, :raw]) do
      {:ok, file} ->
        try do
          with :ok <- start_maintenance_fault(fault, :during_backup_sync, file) do
            :file.sync(file)
          end
        after
          _ = :file.close(file)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sync_directory(path) do
    case :file.open(String.to_charlist(path), [:read, :raw, :directory]) do
      {:ok, directory} ->
        try do
          :file.sync(directory)
        after
          _ = :file.close(directory)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
