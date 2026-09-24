defmodule Foundry.Repair.FR08AProtectedBoundaryTest do
  use ExUnit.Case, async: false

  alias Foundry.Repair.{FR08AProtectedBoundary, FR08HandoffGate}

  test "all six revision-bound protected capabilities pass substantive public probes" do
    report = FR08AProtectedBoundary.report()

    assert report.identity.implementation_binding == "verified:source-sha256+beam-md5/v1"
    assert report.identity.subject_revision == "b1a820e888f228b14be8d6d8843b8b88287ff8be"
    assert report.identity.subject_tree == "88b07e68bad0a5638528c229bb087881e58f40f1"
    assert length(report.identity.exercised_api) == 10
    assert FR08HandoffGate.ready?(report.gate)
    assert report.gate.passed_count == 6
    assert report.gate.failed_count == 0
    assert report.gate.unavailable_count == 0

    assert Enum.all?(report.gate.capabilities, fn capability ->
             capability.status == "passed" and
               String.starts_with?(capability.evidence, "fr08a:") and
               String.contains?(capability.evidence, ":sha256:")
           end)
  end

  test "revision mismatch cannot claim readiness" do
    report =
      FR08HandoffGate.run(FR08AProtectedBoundary,
        subject_revision: "0000000000000000000000000000000000000000"
      )

    refute FR08HandoffGate.ready?(report)
    assert report.unavailable_count == 6
  end

  test "frozen artifact is deterministic and bound to the protected sources" do
    first = FR08AProtectedBoundary.report_artifact()
    second = FR08AProtectedBoundary.report_artifact()
    foundry_root = Path.expand("../../..", __DIR__)

    assert first == second
    assert first == File.read!(Path.join(foundry_root, "docs/fr-08/fr08a-protected-report.txt"))
    assert first =~ "ready=true\n"
    assert first =~ "implementation_binding=verified:source-sha256+beam-md5/v1\n"

    assert first =~
             "protected_primitives.ex|sha256:945f0234bb35a5ddd10f1f7ce568ce85d06cd5466722d5840b7d6985019e32f4|beam_md5:4c19d74f30d5d0a235de52f52bdd279a"

    assert first =~
             "gateway.ex|sha256:eee5450923cf00b8dc3bddd462ca474efe25de91b55b9b2f0ed463f5984dd8f1|beam_md5:ee302f23f9e793519c7b4745c8b5af10"
  end

  test "changed loaded Gateway implementation refuses all positive evidence" do
    foundry_root = Path.expand("../../..", __DIR__)
    fixture = Path.join(foundry_root, "test/support/fr08a_identity_negative_fixture.exs")

    {output, 0} =
      System.cmd(System.find_executable("mix"), ["run", "--no-start", "--no-compile", fixture],
        cd: foundry_root,
        env: [{"COORDINATOR_TICK", "0"}, {"HERDR_ENV", nil}]
      )

    assert output == "identity_mismatch_refused\n"
  end
end
