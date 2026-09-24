defmodule Foundry.ManualLane.StartupTest do
  @moduledoc """
  Lane mode as a release starts it: the flag makes the node a lane daemon, the only daemon; its
  supervisor runs ManualLane.Server alone, and the store settings come from env vars
  (`bin/foundry-lane`), seeded from the shipped example policy.
  """
  use ExUnit.Case, async: false

  alias Foundry.Application, as: App
  alias Foundry.DurableStore.Gateway
  alias Foundry.ManualLane.Server

  @example Path.expand("../../../docs/batch-d/lane-policy.example.json", __DIR__)
  @env ~w(FOUNDRY_MANUAL_LANE PRAMANA_STARTUP_MODE FOUNDRY_MANUAL_LANE_REPO
          FOUNDRY_MANUAL_LANE_POLICY FOUNDRY_MANUAL_LANE_STORE)

  setup do
    saved = Map.new(@env, &{&1, System.get_env(&1)})

    on_exit(fn ->
      for {var, value} <- saved,
          do: if(value, do: System.put_env(var, value), else: System.delete_env(var))
    end)

    Enum.each(@env, &System.delete_env/1)

    root =
      Path.join(
        if(File.dir?("/private/tmp"), do: "/private/tmp", else: System.tmp_dir!()),
        "manual-lane-startup-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  test "the lane flag is the only daemon; without it the node is a child-less client" do
    assert App.startup_mode() == :client
    assert App.runtime_children(:client) == []
    # The retired daemon switch no longer starts anything.
    System.put_env("PRAMANA_STARTUP_MODE", "daemon")
    assert App.startup_mode() == :client
    System.put_env("FOUNDRY_MANUAL_LANE", "1")
    assert App.startup_mode() == :lane
  end

  test "the lane supervisor runs ManualLane.Server alone, from env config and the example policy",
       ctx do
    store = Path.join(ctx.root, "store/authority.sqlite3")
    System.put_env("FOUNDRY_MANUAL_LANE_REPO", ctx.root)
    System.put_env("FOUNDRY_MANUAL_LANE_POLICY", @example)
    System.put_env("FOUNDRY_MANUAL_LANE_STORE", store)

    sup =
      start_supervised!(%{
        id: :lane_supervisor,
        type: :supervisor,
        start: {Supervisor, :start_link, [App.runtime_children(:lane), [strategy: :one_for_one]]}
      })

    ids = for {id, _pid, _type, _modules} <- Supervisor.which_children(sup), do: id
    assert ids == [Server]

    context = Server.context()
    assert context.repo == ctx.root
    assert context.store_path == store
    assert Gateway.status(context.gateway).mode == :ready

    assert {:ok, %{"value" => policy}} =
             Gateway.protected_query(context.gateway, context.capability, %{
               "schema_version" => 1,
               "type" => "policy",
               "policy_id" => "manual-lane"
             })

    assert policy["independent_of_roles"] == %{"reviewer" => ["developer"]}
  end

  test "bin/pramana sends lane commands to the lane node, and only lane commands", ctx do
    fake = Path.join(ctx.root, "fake-release")
    File.write!(fake, "#!/bin/sh\nprintf '%s' \"node=${RELEASE_NODE:-default}\"\n")
    File.chmod!(fake, 0o700)
    wrapper = Path.expand("../../../bin/pramana", __DIR__)
    env = [{"PRAMANA_RELEASE", fake}, {"RELEASE_NODE", nil}]

    assert {"node=foundry_lane", 0} = System.cmd(wrapper, ["lane", "status"], env: env)
    assert {"node=default", 0} = System.cmd(wrapper, ["ticket", "list"], env: env)
  end

  test "without the repo env var, the lane refuses to start", ctx do
    System.put_env("FOUNDRY_MANUAL_LANE_POLICY", @example)
    System.put_env("FOUNDRY_MANUAL_LANE_STORE", Path.join(ctx.root, "authority.sqlite3"))

    assert {:error, {:manual_lane_repo_missing, _}} = start_supervised(Server)
  end
end
