defmodule Foundry.Repair.FR08AProtectedBoundaryTest do
  use ExUnit.Case, async: false

  alias Foundry.Repair.{FR08AProtectedBoundary, FR08HandoffGate}

  test "all six revision-bound protected capabilities pass substantive public probes" do
    report = FR08AProtectedBoundary.report()

    assert report.identity.implementation_binding == "verified:source-sha256+beam-md5/v1"
    assert report.identity.subject_revision == "b5c2da1796e1cd614e22d42e211414d65c966001"
    assert report.identity.subject_tree == "5131fa15b1a1e61c91fe73431c64f22da51e9d4d"
    assert length(report.identity.exercised_api) == 19
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
             "protected_primitives.ex|sha256:e7c8f65335f2391f0236dcdc94113faf85d4b0e40bc150487d0a37f9c5de9898|beam_md5:cfac190b00efc843823a2e5a5f4aec00"

    assert first =~
             "gateway.ex|sha256:d57c730b810e36358096631b7a86bc093685255e692456480970b50bd44390cf|beam_md5:9fcc80699c9dff0d217a7ded998b8687"
  end

  test "changed loaded Gateway implementation refuses all positive evidence" do
    foundry_root = Path.expand("../../..", __DIR__)
    fixture = Path.join(foundry_root, "test/support/fr08a_identity_negative_fixture.exs")

    {output, 0} =
      System.cmd(System.find_executable("mix"), ["run", "--no-start", "--no-compile", fixture],
        cd: foundry_root
      )

    assert output == "identity_mismatch_refused\n"
  end
end
