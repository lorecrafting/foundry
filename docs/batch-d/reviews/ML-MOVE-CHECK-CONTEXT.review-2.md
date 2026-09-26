# ML-MOVE-CHECK-CONTEXT independent correction re-review

**Verdict: correction.** Candidate `6429ff79e4543fe8f64da3d31c71e0787800be85`, base `246bdf958e4c6897e6a2168f4a17755c69633028`, reviewer `agent:codex-gpt-6-astra/review-ML-MOVE-CHECK-CONTEXT-2`.

Reviewed the packet, brief, previous review, blocker, standing instructions, current checker, full base-to-tip test diff and previous-candidate-to-tip correction. Detached reviewer worktree `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-2` is clean at the exact candidate. The complete base-to-tip range changes only the two authorized paths: `bin/check_move.exs` and `test/foundry/compiled_move_check_test.exs`.

## Ranked finding

1. **P1 — Capture owner and key still do not preserve local versus remote capture identity when nothing moves.** `bin/check_move.exs:201–210,254–261,272–285`. Both capture normalization branches produce the same term; `capture_targets/3` records only owner and key. Consequently `same_capture?/4` accepts a local-to-remote rewrite within the same unchanged owner. This is distinct from the permitted local-to-imported change required by a module split: there is no relocated definition in this fixture.

   Base:

   ```elixir
   defmodule Flavor.Owner do
     def captures, do: {&helper/1, &Flavor.Owner.helper/1}
     def helper(v), do: v + 1
   end
   ```

   Candidate changes only `captures/0` to:

   ```elixir
   def captures, do: {&Flavor.Owner.helper/1, &Flavor.Owner.helper/1}
   ```

   Independently compiled both versions with `elixirc --warnings-as-errors`, successfully. `{a, b} = Flavor.Owner.captures(); a == b` changes **false → true**. The candidate checker exits **0**, `compiled definitions match`. The admitted-base checker exits **1**, `compiled definitions differ`, on those same BEAMs. This is a newly admitted observable behavior change under the complete ticket delta, although the latest correction did not itself introduce the normalization.

   Preserve capture kind for retained-owner comparisons and permit the necessary local-to-imported normalization only with evidence of the permitted relocation. Add a controlled retained-owner local/remote regression alongside the existing moved-import positive case. No expansion to arbitrary behavioral equivalence is requested.

## Previous findings and independent probes

The original same-body wrong-owner, unresolved-target and unchanged duplicate-key findings are corrected in the fixtures independently rerun here:

- Remote same-body wrong owner: refused, including two captures in one body (runtime equality true → false).
- Local/remote same-body wrong owner across a split: refused (runtime equality false → true).
- Changed missing target: refused. The focused suite also refuses an unchanged unresolved target. These unresolved fixtures emit undefined-function warnings and are not warnings-as-errors evidence.
- Unchanged duplicate-key definitions with different local target bodies: accepted.
- Two retained capture-bearing owners with identical bodies and multiple remote captures: unchanged accepted; reversing targets in the second owner refused.
- Two same-body moved capture-bearing candidates without retained owners: refused as ambiguous. This is a conservative limitation; there is no unique pairing proof, so it is not ranked as a correctness defect.
- Genuine unique-owner move with default `/0` capture: accepted.
- Genuine unique-owner move with a capture nested in an anonymous function: accepted.
- Unchanged relocated anonymous rescue: accepted; changed exception class `ArgumentError` to `RuntimeError`: refused.
- Retained-owner local-to-remote rewrite: incorrectly accepted, as ranked above.

The probe script contains **12 cases**. Its sources, BEAMs and runtime equality observations are independently generated from controlled fixtures; it does not patch candidate code. Artifacts:

- `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-2-probes.exs`
- `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-2-probes.txt`
- `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-2-fixtures/`

## Checks actually run

- `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix test test/foundry/compiled_move_check_test.exs`: **10 passed, 0 failed**.
- Exact candidate checker against existing PP base/candidate BEAMs, all ten declared additions and `--lint-protected /private/tmp/ML-DECOMPOSE-PP-dev/lib/foundry/durable_store/protected/*.ex`: **exit 0**, `compiled definitions match`; base **337**, candidate **347** source definitions. The PP checkout was read only and was not recompiled.
- Both retained-owner regression sources compiled separately with `elixirc --warnings-as-errors`: **exit 0** each.
- Admitted-base checker on the same retained-owner regression BEAMs: **exit 1**, confirming the false pass was introduced in the full ticket range.
- Final reviewer Git status: clean; HEAD equals the exact reviewed candidate.

No full gate, broad suite, FR-08A rebind, provider session, integration edit or candidate edit ran. Developer-reported mutation controls were not repeated and are not claimed as independent reviewer mutations. This correction verdict does not certify the new guard as complete.

## Separate Ponytail Review and test quality

**Lean already. Ship.** Complexity-only review found no safe deletion or speculative abstraction in the actual delta; this does not override the correctness finding. The three correction tests each guard a distinct reproduced failure. The existing moved-import and rescue tests retain useful positive and negative cases. The missing regression concerns retained-owner capture kind, not extra coverage for its own sake.

This review is to be recorded through the reviewer principal's own `lane review`, then confirmed through status/log and the completed receipt; this notes file alone is not the verdict receipt.
