# ML-MOVE-CHECK-CONTEXT independent review 3

**Verdict: correction.** Candidate `5ecd585d6c94a8dde48cad2983aaee85e7632036`, admitted base `246bdf958e4c6897e6a2168f4a17755c69633028`, reviewer `agent:codex-gpt-6-astra/review-ML-MOVE-CHECK-CONTEXT-3`.

Reviewed the packet, developer brief, standing instructions, two previous recorded reviews, the complete base-to-tip diff and the latest correction separately. Detached reviewer checkout `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-3` is clean at the exact candidate. Scope is exactly the two authorized files: `bin/check_move.exs` and `test/foundry/compiled_move_check_test.exs` (309 insertions, 12 deletions). No candidate, PP developer or integration source was edited.

## Ranked finding

1. **P1 — Moving the enclosing definition does not establish that changing capture kind preserves behavior.** `bin/check_move.exs:42–54,280–284`. The new guard permits any capture-kind change whenever the enclosing definition has a unique new owner. Its target comparison then accepts the unchanged captured owner immediately. As a result, moving only `captures/0` bypasses the retained-target local/remote distinction just added by this correction.

   Base:

   ```elixir
   defmodule Retained.A do
     def captures, do: {&helper/1, &Retained.A.helper/1}
     def helper(v), do: v + 1
   end
   ```

   Candidate:

   ```elixir
   defmodule Retained.A do
     def helper(v), do: v + 1
   end
   defmodule Retained.B do
     def captures, do: {&Retained.A.helper/1, &Retained.A.helper/1}
   end
   ```

   Both sources compile independently with `elixirc --warnings-as-errors` (exit 0). For `{a, b} = captures()`, `{a == b, a.(4), b.(4)}` changes **`{false, 5, 5}` → `{true, 5, 5}`**. The captured helper never moves. Nevertheless, the candidate checker exits **0**, `compiled definitions match`, when invoked with these BEAM directories and module sets `Retained.A` and `Retained.A,Retained.B`. The admitted-base checker exits **1**, `compiled definitions differ`, on exactly those BEAMs, establishing a false pass introduced by this ticket range.

   The reverse direction also fails: base `ReverseMove.A.captures/0` returns two remote captures of `ReverseMove.B.helper/1`; move `captures/0` into B and change only its first capture to local `&helper/1`. B's helper remains unchanged. Both sources compile with warnings as errors; equality changes **true → false**, and the candidate checker again exits **0**. This is the same root cause, not a separate finding.

   The author's unique-enclosing-move inference is insufficient. Preserve the demonstrated retained-target distinction even when its caller moves, and constrain any permitted capture-kind rewrite with evidence appropriate to the actual target relocation. Add the smallest regression for this concrete counterexample. This review does not request a general behavioral-equivalence solver.

## Checks and independent evidence

- `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix test test/foundry/compiled_move_check_test.exs`: **11 passed, 0 failed**.
- **19 independently compiled probe cases**, emitted by `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-3-probes.exs`. Twelve previous review cases were adapted to the exact new checker; seven extend them. Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-3-probes.txt`; sources and BEAMs: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-3-fixtures/`.
- Both retained-caller local→remote and remote→local rewrites are now refused. Same-body wrong owner, changed missing target, changed duplicate-owner capture order and ambiguous multiple moved owners are refused. Unchanged duplicate-key owners, legitimate moved default capture and nested capture are accepted.
- Imported-capture positive case accepts with result **[5] → [5]**; wrong imported target refuses with result **[5] → [3]**. Anonymous rescue relocation accepts with result **:handled → :handled**; altered rescue result refuses with **:handled → :changed**; changed exception class also refuses.
- Both new moved-caller counterexamples were additionally compiled in separate `elixirc --warnings-as-errors` processes: **four successful compilations**, no warnings. Missing-target fixtures intentionally emit undefined-function warnings and are not warnings-as-errors evidence.
- The exact candidate checker passes the real uncommitted PP split using the existing base/candidate BEAM directories, all ten declared additions and `--lint-protected /private/tmp/ML-DECOMPOSE-PP-dev/lib/foundry/durable_store/protected/*.ex`: **exit 0**, `compiled definitions match`. Counts: base **337**, candidate **347** source definitions (24 facade, 68 Rows, 29 Guards, 25 ReadSet, 51 Reads, 49 TransitionReplay, 33 Operations, 68 RestartCheck). PP source was read only; it was not recompiled.
- `git diff --check <base> HEAD`: exit 0. Final candidate checkout remains clean at the reviewed SHA.

## New test and independent red control

The new retained-owner test detects a distinct regression and uses a controlled compiled fixture with an independent expected refusal. In a scratch checker only, changed the exact expression `(before_kind == after_kind or enclosing_moved?) and` to `(before_kind == after_kind or enclosing_moved? or true) and`. Ran the candidate test file directly with ExUnit from that scratch directory. **10 passed, 1 failed**: the new test at line 289 fails at line 313, `assert status != 0`, with `left: 0` and `Assertion with != failed, both sides are exactly equal`. Output is `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-3-red.txt`; deliberately mutated checker is under `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-3-red/`. The candidate checker was never mutated. This independently confirms that the test exercises the guard, but the counterexamples above show the guard is incomplete.

## Separate Ponytail Review

**Lean already. Ship.** Complexity-only review of the actual diff found no safe deletion or speculative abstraction. This does not override the correctness finding.

## Limitations and receipt

No full gate, broad suite, FR-08A rebind, provider session or integration ran. This is a focused correctness review, not certification of arbitrary module-refactoring equivalence. Conservative refusal of ambiguous multiple-owner moves remains a limitation; it is not a false-pass finding here.

This review is recorded by the reviewer principal's own `lane review` command; the resulting receipt and lane status/log are checked separately. The notes file alone is not a receipt.
