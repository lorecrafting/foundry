defmodule PramanaFoundry.HardeningPMTest do
  @moduledoc """
  HardeningPM fills a bare IMPRV- ticket with a default scope, then refuses any scope outside
  it. Since the split the repository root is the Foundry project, so both are
  `lib/pramana_foundry/`, not the monorepo's `workflow/lib/...`.
  """
  use ExUnit.Case, async: true

  alias PramanaFoundry.HardeningPM

  test "a bare IMPRV- ticket is scoped to lib/pramana_foundry/** and passes the leak check" do
    amendments = Map.new(HardeningPM.build_amendments(%{"task_id" => "IMPRV-000"}))

    assert amendments["scope"] == ["lib/pramana_foundry/**"]
    assert amendments["exclusions"] == ["No changes outside lib/pramana_foundry/"]
    assert HardeningPM.validate_no_scope_leak([%{"ticket" => amendments}]) == :ok
  end

  test "the leak check refuses the monorepo layout" do
    assert {:error, _} =
             HardeningPM.validate_no_scope_leak([
               %{"ticket" => %{"scope" => ["workflow/lib/pramana_foundry/**"]}}
             ])
  end
end
