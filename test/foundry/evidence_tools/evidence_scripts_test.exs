defmodule Foundry.EvidenceTools.EvidenceScriptsTest do
  # Runs the evidence scripts as they are run by hand, so there is one copy of their logic.
  # Both halt the VM on a failed red control, which is why they run in a child `elixir`.
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)

  # The refusal sites no `require_*` call reaches, so no guard mutation trial exists for them.
  # A new one fails here until it is added deliberately: add a refusal test pinned to its atom,
  # or move it into a `require_*` guard, then update this table from the script's output.
  @outside """
    cancellation.ex do_transition 4  integration_occurred, invalid_cancellation_disposition, no_integration_to_finalize, ticket_terminal
    event.ex validate          2  invalid_semantic_event
    executions.ex add_execution 2  execution_already_exists, invalid_execution_identity
    executions.ex open_attempt 2  attempt_already_exists, retained_attempt_must_be_reused
    kernel.ex apply            2  kernel_raised, unknown_entity_kind
    kernel.ex check_entity_addressing 2  entity_id_disagrees_with_payload, invalid_control_entity
    kernel.ex check_revision   2  stale_entity_revision
    kernel.ex resolve_entity   2  entity_already_exists, unknown_entity
    tickets.ex do_transition   2  invalid_admission_phase, resume_phase_disagrees
    checks.ex add_check        1  check_already_exists
    developer.ex do_transition 1  invalid_freeze_disposition
    integration.ex do_transition 1  invalid_integration_outcome
    kernel.ex check_sequence   1  out_of_order_event
    kernel.ex check_state      1  invalid_state
    kernel.ex refuse_terminal_ticket 1  ticket_terminal
    plan.ex bind_allocation    1  allocation_read_unbound
    plan.ex decision           1  allocation_read_unbound
    plan.ex expected_revisions 1  invalid_fact_key
    planning.ex do_transition  1  duplicate_proposal
  """

  defp run(script, args \\ []) do
    System.cmd(System.find_executable("elixir"), [script | args],
      cd: @root,
      stderr_to_stdout: true
    )
  end

  test "refusal_sites: red control passes and the refusals outside the sweep are acknowledged" do
    {out, status} = run("bin/refusal_sites.exs")
    assert status == 0, out
    assert out =~ "red control passed"
    # Chunks: red control, totals, the outside table, the do_transition split.
    assert Enum.at(String.split(out, "\n\n"), 2) <> "\n" == @outside, out
  end

  test "contract_annotation_diff: red controls pass and it runs against HEAD in this layout" do
    {out, status} = run("bin/contract_annotation_diff.exs", ["HEAD"])
    assert out =~ "red controls passed", out
    assert out =~ ~r/^baseline: \w+ /m, out
    assert out =~ ~r/^markers: [1-9]\d* at the baseline/m, out
    # A committed candidate compares HEAD with itself, so PRESERVED is the only gate outcome;
    # CHANGED is allowed so an uncommitted contract edit is reported by the script, not here.
    assert {status, out =~ "CONTENT PRESERVED"} in [{0, true}, {1, false}], out
    assert status == 0 or out =~ "CONTENT CHANGED", out
  end
end
