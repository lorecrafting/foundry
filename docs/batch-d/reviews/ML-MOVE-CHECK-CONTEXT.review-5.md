# ML-MOVE-CHECK-CONTEXT independent review 5

**Verdict: approved, within the bounded direct-mapper contract.** Candidate `70dd91c2a5735594f2eb42a01c177adb269946c4`; admitted base `246bdf958e4c6897e6a2168f4a17755c69633028`; reviewer `agent:codex-gpt-6-astra/review-ML-MOVE-CHECK-CONTEXT-5`.

## Scope and findings

No blocking finding under the correction-5 brief and review-4 supplement's explicit contract. Reviewed the packet, developer/reviewer briefs, four previous reviews and supplement, repository instructions and the complete base-to-tip two-file delta. Detached `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5` is clean at the exact candidate. Scope is only `bin/check_move.exs` and `test/foundry/compiled_move_check_test.exs`: 434 insertions, 12 deletions. Latest correction alone is 100 insertions, 13 deletions. Candidate, integration and PP developer sources were not edited.

`capture_targets/4` recognizes the compiler-resolved `Enum.map/2` and `Enum.flat_map/2` nodes and marks only their second argument. Generic tuple/list descent resets that permission, and the input argument starts unmarked. `same_capture?/5` permits a kind rewrite only with both direct-context flags, arity one, moved caller, unique moved target correspondence and equal nonmissing target bodies. Captures of retained targets retain their kind requirement. Both review-4 identity-collapse counterexamples now refuse.

## Checks actually run

- `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix test test/foundry/compiled_move_check_test.exs`: **13 passed, 0 failed**. Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-tests.txt`.
- **21 previous compiled probes**, independently regenerated against this checker: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-probes.exs`, output `.txt`, fixtures `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-fixtures/`. Same-body wrong owner, missing target, retained-owner kind changes in both directions, moved caller with retained target in both directions, changed duplicate-owner capture order, ambiguous multiple moved owners, wrong imported target, changed rescue class/result, and both tuple/cross-definition collapse cases refuse. Unchanged duplicate keys, intended imported target and unchanged rescue accept. Previously accepted default `/0` and nested returned captures now refuse, as the tighter contract requires. Missing-target probes intentionally emit undefined-function warnings and are not warnings-as-errors evidence.
- Runtime tuple-collapse result remains **`{false, 5, 5}` → `{true, 5, 5}`**, and cross-definition equality remains **false → true**; checker exits **1** for both. Intended imported mapper yields **[5] → [5]**, wrong import yields **[5] → [3]** and refuses. Rescue unchanged yields **:handled → :handled**, changed result yields **:handled → :changed** and refuses.
- **17 additional compiled context probes**, with **34 successful independent `elixirc --warnings-as-errors` compilations**. Direct map, direct flat_map, alias-resolved Enum, imported Enum.map, and an inner direct Enum mapper nested in an outer lambda accept; their runtime outputs match across revisions. Returned tuple, list, map, lambda-returned capture beneath Enum, list nested in mapper position, intermediate variable, Enum.each, arbitrary local callback, capture in Enum's input, alias to List, exact `map/2` on a lookalike custom module, and direct arity-two capture refuse. Main script/output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-context.exs` and `.txt`; additional arity/lookalike sources and BEAMs: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-boundaries/`. Together the old and new controls cover **38 compiled comparisons: 10 accepted, 28 refused**, with expected statuses.
- Exact checker against real existing PP base/candidate BEAMs, **all ten declared additions** and `--lint-protected` over all Protected source files: **exit 0, compiled definitions match**. Base **337**, candidate **347** definitions: facade 24, Rows 68, Guards 29, ReadSet 25, Reads 51, TransitionReplay 49, Operations 33, RestartCheck 68. Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-pp.txt`. PP was read only and not recompiled.
- `git diff --check <admitted-base> HEAD`: exit 0. Final candidate checkout remains clean at the reviewed SHA.

## Independent red control and test quality

In a scratch checker only, replaced exact expression `enclosing_moved? and target_moved? and elem(key, 1) == 1 and before_direct? and\n            after_direct?` with `enclosing_moved? and target_moved?`. Ran the candidate test file with ExUnit from `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-red`. **12 passed, 1 failed**: new test at line 352 fails at line 411, `assert status != 0`, `left: 0`, `Assertion with != failed, both sides are exactly equal`. Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-red.txt`. An initial invocation loaded the test before starting ExUnit and was discarded; the cited completed run starts ExUnit first. Candidate code was never mutated.

The new test protects a distinct observed regression with independent literal runtime equality expectations, using two minimal shapes for within-definition and cross-definition identity collapse. Existing wrong-owner, retained-target, missing-target, duplicate-key, imported-capture and rescue tests remain relevant. Separate compiled context probes establish the immediate-parent boundary rather than treating a green mutation test as completeness proof.

## Bounded claim and observed limitation

Approval covers preserved target invocation for the recognized direct mapper uses under ordinary traversal and a fixed code generation. It does **not** certify unrestricted capture-value or runtime equivalence. Runtime code replacement, tracing/stack inspection, custom Enumerable behavior, deliberate closure introspection and helper side effects remain outside that claim, as explicitly established in the review-4 supplement.

I confirmed the introspection limitation rather than assuming it: pass an `Enumerable.Function` to the accepted `direct_map` fixture. Its reducer obtains `{:env, [wrapper]} = :erlang.fun_info(reducer, :env)` and then `{:env, [mapper]} = :erlang.fun_info(wrapper, :env)`, returning the mapper's function type as its result. The same input makes the base return **[:local]** and candidate return **[:external]**, both exit 0, although the checker accepts the definitions. Output: `/private/tmp/ML-MOVE-CHECK-CONTEXT-review-5-limitation.txt`. Thus the checker comment “before it can escape” is shorthand for the bounded ordinary-consumer assumption, not a universal non-escape guarantee. This is an explicitly excluded behavior, not a newly asserted general-equivalence guarantee or a blocking defect within the approved brief.

## Separate Ponytail Review

**Lean already. Ship.** Complexity-only review of the actual diff found no safe deletion or speculative abstraction. The small immediate-context flag avoids introducing generic escape/effect or capture-identity analysis. This assessment is separate from correctness and does not broaden the bounded approval.

## Limits and receipt

No full gate, broad suite, FR-08A rebind, provider session or integration ran. No claim is made that the PP split itself has completed review or integration. Conservative refusal of ambiguous relocation and non-direct kind changes is intentional.

The reviewer records its own lane verdict using this exact candidate and notes path, then confirms the returned receipt and status/log. The notes file alone is not a completed lane verdict.
