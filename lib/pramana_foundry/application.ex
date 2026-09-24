defmodule PramanaFoundry.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    mix_env = mix_env()
    mode = if mix_env == :test, do: :client, else: startup_mode()
    operator_root = PramanaFoundry.RuntimeRoot.initialize_operator_root!()
    PramanaFoundry.RuntimeRoot.resolve_and_publish!(mix_env, operator_root)

    Supervisor.start_link(runtime_children(mode),
      strategy: :one_for_one,
      name: PramanaFoundry.Supervisor
    )
  end

  @doc """
  The children each startup mode runs. The manual lane is the only daemon: `:lane` runs
  `ManualLane.Server` alone, and its store's own owner lock and unclean marker fence it and
  route a crash to `lane recover`. Everything else (tests, release `eval`/`rpc` clients)
  starts no children.
  """
  @spec runtime_children(:client | :lane) :: [module()]
  def runtime_children(:client), do: []

  def runtime_children(:lane) do
    IO.puts("PramanaFoundry starting: manual lane")
    [PramanaFoundry.ManualLane.Server]
  end

  @doc false
  # `bin/foundry-lane` exports the flag; a release boots with plain args such as
  # ["--no-halt"], so the args cannot tell a daemon from a client.
  @spec startup_mode() :: :client | :lane
  def startup_mode, do: if(manual_lane_enabled?(), do: :lane, else: :client)

  @doc false
  @spec manual_lane_enabled?() :: boolean()
  def manual_lane_enabled? do
    System.get_env("FOUNDRY_MANUAL_LANE") == "1" ||
      Keyword.get(Application.get_env(:pramana_foundry, :manual_lane, []), :enabled, false)
  end

  defp mix_env do
    if Code.ensure_loaded?(Mix) and function_exported?(Mix, :env, 0),
      do: apply(Mix, :env, []),
      else: :prod
  end
end
