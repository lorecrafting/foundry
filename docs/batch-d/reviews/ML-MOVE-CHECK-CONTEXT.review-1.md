# ML-MOVE-CHECK-CONTEXT independent review

**Verdict: correction.** Exact candidate `9b3dcd4852e74121038d6f3fd3c1734beda0b8f9`; base `246bdf958e4c6897e6a2168f4a17755c69633028`; independent reviewer principal `agent:codex-gpt-6-astra/review-ML-MOVE-CHECK-CONTEXT`.

Reviewed the packet, brief, PP blocker, repository standing instructions, four precision-tool reviews, and complete candidate diff in detached `/private/tmp/ML-MOVE-CHECK-CONTEXT-review`. The only changed paths are the two authorized files: `bin/check_move.exs` and `test/foundry/compiled_move_check_test.exs`. No candidate or PP/developer/integration source was edited. No full gate or FR-08A rebind ran.

## Ranked findings

1. **P1 — Equal current bodies do not establish capture target identity.** `bin/check_move.exs:42–47,195–199,261–266`. `normalize/2` discards split capture owners; `capture_body/2` then compares only normalized definitions, so switching to a different owner with the same body passes. Independently compiled the following base and candidate with `elixirc --warnings-as-errors` (both exit 0):

   ```elixir
   defmodule Remote.Entry do
     # Base:
     def captures, do: {&Remote.Owner.helper/1, &Remote.Owner.helper/1}
     # Candidate replaces only that line with:
     # def captures, do: {&Remote.Other.helper/1, &Remote.Owner.helper/1}
   end
   defmodule Remote.Owner do
     def helper(v), do: v + 1
   end
   defmodule Remote.Other do
     def helper(v), do: v + 1
   end
   ```

   All three module names remain unchanged between revisions. The checker exits **0**, `compiled definitions match`, but `{a, b} = Remote.Entry.captures(); a == b` changes **true → false**. This is a real observable value change, independent of any permitted module relocation. A separate local-to-remote capture fixture also passes with changed capture equality **false → true**. Preserve provable target correspondence, or refuse ambiguous ownership; matching body text alone cannot meet the ticket's wrong-owner requirement. Add a same-body wrong-owner control alongside the existing different-body test.

   Related fail-open case: `capture_body/2` returns `nil` for missing targets. A base capture of `Missing.A.absent/1` changed to `Missing.B.absent/1`, with both empty target modules included in the split set, also exits **0** because `[nil] == [nil]`. These fixtures compile with undefined-function warnings, so they do not satisfy warnings-as-errors compilation; nevertheless the standalone checker currently claims equivalence without resolving either target. Refuse unresolved capture targets explicitly rather than treating missing definitions as equal evidence.

2. **P2 — Cross-product pairing rejects unchanged duplicate-key definitions.** `bin/check_move.exs:42–47`. The nested comprehension compares every base/candidate pair having the same function key and normalized body, even when those definitions belong to different owners. A byte-identical base and candidate containing these two modules is rejected with `capture target differs: {:capture, 0}`:

   ```elixir
   defmodule Duplicate.A do
     def capture, do: &helper/1
     def helper(v), do: {:a, v}
   end
   defmodule Duplicate.B do
     def capture, do: &helper/1
     def helper(v), do: {:b, v}
   end
   ```

   The candidate checker exits **1** while the admitted-base checker exits **0** on the same compiled fixtures. Each owner's capture resolves correctly, but the new loop compares A's base target against B's candidate target. Bind matching definitions and capture targets consistently, or use a comparison that preserves multiplicity and target correspondence; do not require every cross-pair to agree. Add this unchanged-input regression test.

## Verification actually run

- `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix test test/foundry/compiled_move_check_test.exs`: **7 passed, 0 failed**. No broad suite was run.
- Independently ran this candidate's checker against the actual PP base and candidate BEAM directories named in the blocker, using all ten declared additions and the required Protected source lint. **Exit 0, compiled definitions match**: base **337**, candidate **347** source definitions (24 facade, 68 Rows, 29 Guards, 25 ReadSet, 51 Reads, 49 TransitionReplay, 33 Operations, 68 RestartCheck). The PP worktree was read only.
- Eight independent compiled fixture cases: local/remote same-body wrong owner incorrectly accepted; missing targets incorrectly accepted; unchanged duplicate keys incorrectly refused; moved default `/0` capture accepted; capture nested inside an anonymous function accepted; unchanged anonymous rescue accepted; changed exception class `ArgumentError → RuntimeError` correctly refused; remote-only same-body wrong owner incorrectly accepted. (The local/remote case and the remote-only case are separate fixtures.)
- The focused suite also verifies the changed rescue result and different-body imported target are refused. These controls establish the narrow fixes, but miss both ranked findings.
- Both versions of the remote-only wrong-owner fixture compile independently with warnings as errors. Runtime capture equality was observed before and after loading candidate modules.
- Ran the admitted-base checker on the unchanged duplicate-key fixture; it accepts, confirming finding 2 is introduced by this candidate.

The developer's reported three mutation controls were not rerun or claimed as independent reviewer mutations. No newly implemented guard is being certified by this correction review.

## Test quality and separate Ponytail Review

The two added tests cover distinct useful regressions: imported capture context and anonymous rescue context. Their positive/negative cases use controlled compiled inputs and independent expected outcomes. They need the substantive same-body-owner and duplicate-key cases above; no coverage-only expansion is requested.

Complexity-only review of the actual diff: **Lean already. Ship.** No safe deletion or speculative subsystem identified; **net: -0 lines possible**. This assessment does not override the correctness findings. The six-field definition record is a small extension to existing machinery; the defect is what its body comparison proves.

## Reproduction artifacts and receipt

- `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-probes.exs` — run with `elixir`; independently compiles all eight cases and invokes the exact candidate checker.
- `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-probes.txt` — observed checker statuses and runtime values.
- `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-fixtures/` — emitted source and BEAMs per case, including the warnings-as-errors remote fixture.
- `/private/tmp/ML-MOVE-CHECK-CONTEXT-base-checker.exs` — admitted-base checker used only for the duplicate-key regression control.

Reviewer worktree remains clean at the exact candidate. This verdict is to be recorded by the reviewer principal through `lane review` and confirmed through lane status/log; the notes file alone is not a completed receipt.
