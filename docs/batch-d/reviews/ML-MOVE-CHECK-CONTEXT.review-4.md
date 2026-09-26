# ML-MOVE-CHECK-CONTEXT independent review 4

**Verdict: correction.** Candidate `ada78eaf440ce529e5bcaaefee27b47eb7170f1a`, admitted base `246bdf958e4c6897e6a2168f4a17755c69633028`, reviewer `agent:codex-gpt-6-astra/review-ML-MOVE-CHECK-CONTEXT-4`.

Reviewed the packet, developer brief, previous three reviews, repository instructions, full base-to-tip diff and latest correction separately. Detached checkout `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4` is clean at the exact candidate. The complete range changes only the authorized `bin/check_move.exs` and `test/foundry/compiled_move_check_test.exs`: 347 insertions, 12 deletions. No candidate, integration or PP developer source was edited.

## Ranked finding

1. **P1 — Unique relocation of both definitions still does not preserve capture identity relations.** `bin/check_move.exs:281–294`. The new `target_moved?` proves that one matching helper moved, but the independent per-capture comparison still permits two distinct values to collapse into one. This is a remaining false pass in the full ticket range, not a regression introduced specifically by the latest stricter guard.

   Base:

   ```elixir
   defmodule Collapse.Before do
     def captures, do: {&helper/1, &Collapse.Before.helper/1}
     def helper(v), do: v + 1
   end
   ```

   Candidate:

   ```elixir
   defmodule Collapse.Owner do
     def helper(v), do: v + 1
   end
   defmodule Collapse.After do
     import Collapse.Owner, only: [helper: 1]
     def captures, do: {&helper/1, &Collapse.Owner.helper/1}
   end
   ```

   Both sources compile independently with `elixirc --warnings-as-errors`, exit 0. Both the enclosing function and helper have unique new owners, satisfying the new proof. Nevertheless, for `{a, b} = captures()`, runtime `{a == b, a.(4), b.(4)}` changes **`{false, 5, 5}` → `{true, 5, 5}`**. The exact candidate checker exits **0**, `compiled definitions match`; the admitted-base checker exits **1**, `compiled definitions differ`, on these same BEAMs.

   Reproduce with `elixir /private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-probes.exs`, case `moved_target_identity_collapse`. Direct checker invocation:

   ```sh
   elixir /private/tmp/ML-MOVE-CHECK-CONTEXT-review-4/bin/check_move.exs /private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-fixtures/moved_target_identity_collapse/base /private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-fixtures/moved_target_identity_collapse/candidate Collapse.Before Collapse.After,Collapse.Owner
   ```

   Preserve the demonstrated capture-identity distinction or establish an explicitly bounded acceptance contract for capture relocation. Another owner-count condition alone does not prove unchanged capture behavior. This does not request a general behavioral-equivalence engine.

## Requested analysis: would a pairwise check suffice?

A scratch checker at `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-pairwise.exs` additionally compares the equality partition of capture descriptors within each matched enclosing definition. This rejects the tuple example above and **still passes the real PP split**, using all ten additions and Protected source lint. Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-pairwise-pp.txt`. No such change was made to the candidate.

That local check is insufficient for the class. Independently compiled a second controlled fixture with base `Cross.Before.first/0` returning `&helper/1`, `second/0` returning `&Cross.Before.helper/1`, and `helper/1` returning `v + 1`. Candidate moves the two callers to `Cross.After`, imports the uniquely moved `Cross.Owner.helper/1`, and rewrites the second reference to `&Cross.Owner.helper/1`. Runtime `first() == second()` changes **false → true**. Both the exact candidate and scratch pairwise checker accept. All four base/candidate compilations for the two new cases pass warnings-as-errors. Reproduction: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-cross.exs`; output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-cross.txt`.

A global injective mapping of capture identities could address these equality relations, but would still be a bounded guarantee: local and external captures also differ in introspection and code-version binding. This is reviewer analysis, not a tested implementation proposal. A narrower claim can cover preserved target/application behavior for reviewed relocation uses; it cannot claim arbitrary capture-value equivalence. Choosing such a contract boundary needs an explicit decision, not another silent weakening of normalization. The real PP comparison passes, but that alone cannot certify all behavior of all captures accepted by this shared checker.

## Checks actually run

- `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix test test/foundry/compiled_move_check_test.exs`: **12 passed, 0 failed**.
- **21 independently compiled probe cases**: 19 previous cases adapted to this exact checker, the tuple collapse case, and the cross-definition collapse case. Sources/BEAMs are under `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-fixtures/`; main script/output are `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-probes.exs` and `.txt`.
- Previous moved-caller/retained-target cases now refuse in both directions. Same-body wrong owner, unresolved target, retained-owner kind rewrite, swapped duplicate-owner targets, changed imported target and changed rescue class/result refuse. Unchanged duplicate keys, default capture relocation, nested capture relocation, intended imported target and unchanged anonymous rescue accept. Ambiguous multiple relocated owners remain conservatively refused.
- Missing-target cases intentionally emit undefined-function warnings; they are not warnings-as-errors evidence.
- Exact candidate checker against the existing real PP base/candidate BEAMs, ten declared additions and Protected source lint: **exit 0**, `compiled definitions match`. Counts: base **337**, candidate **347** source definitions (24 facade, 68 Rows, 29 Guards, 25 ReadSet, 51 Reads, 49 TransitionReplay, 33 Operations, 68 RestartCheck). Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-pp.txt`. PP was read only, not recompiled.
- `git diff --check <admitted-base> HEAD`: exit 0; final Git status clean at the reviewed SHA.

## Focused test and independent red control

The new retained-target test detects a distinct regression and uses a controlled compiled fixture with an independent expected refusal. In a scratch checker only, replaced the exact expression `(before_kind == after_kind or (enclosing_moved? and target_moved?)) and` with `(before_kind == after_kind or enclosing_moved?) and`. Running the candidate test file directly with ExUnit from that scratch directory gives **11 passed, 1 failed**. The new test at line 317 fails at line 348: `assert status != 0`, `left: 0`, `Assertion with != failed, both sides are exactly equal`. Artifact: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-red.txt`; mutated checker under `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-4-red/`. An initial invocation from the wrong scratch working directory was discarded and rerun correctly; only the corrected run is cited here. This demonstrates the added guard is exercised, while the finding establishes its semantic limit.

## Separate Ponytail Review

**Lean already. Ship.** Complexity-only review of the actual diff found no safe deletion or speculative abstraction. This assessment does not override the correctness finding or recommend a growing generic equivalence engine.

## Scope and receipt

No full gate, broad suite, FR-08A rebind, provider session or integration ran. This is focused review of the exact candidate, not certification of arbitrary module refactoring. The reviewer records the verdict through its own `lane review` command and confirms the receipt plus status/log separately; a notes file alone is not a receipt.
