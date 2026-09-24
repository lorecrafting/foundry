defmodule PramanaFoundry.ImproverTest do
  @moduledoc """
  The Improver turns a finding into an IMPRV- create proposal with a fixed scope. Since the
  split the repository root is the Foundry project, so that scope is `lib/pramana_foundry/**`,
  not the monorepo's `workflow/lib/...`.
  """
  use ExUnit.Case, async: true

  alias PramanaFoundry.Improver

  test "a proposed hardening ticket is scoped to lib/pramana_foundry/**" do
    finding = %{category: :crash, summary: "s", details: "d"}

    assert %{"ticket" => ticket} = Improver.proposal(finding, 0, "base")
    assert ticket["scope"] == ["lib/pramana_foundry/**"]
    assert ticket["exclusions"] == ["No changes outside lib/pramana_foundry/"]
  end
end
