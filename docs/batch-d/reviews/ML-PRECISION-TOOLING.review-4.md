# ML-PRECISION-TOOLING independent review 4

**Verdict: approved.** Exact candidate `6330387904bca51574c3325e3f21b7eb3e5af359`; admitted base `c55413fec19b113baa2f463e8dfaeb22674d8f91`; preceding candidate `3d3ec7345148ea36f0d74ba3126ced495784cdfd`. Reviewer principal: `agent:codex-gpt-6-astra/review-ML-PRECISION-TOOLING-4`.

Reviewed the latest correction and complete base-to-candidate scope in detached `/private/tmp/ML-PRECISION-TOOLING-review-4`. All 17 changed paths are within the supplied packet scope. Read the three historical reviews, standing brief, boundary/evidence guidance, and both approved decomposition designs' compiled-move requirements. No blocking correctness findings remain from this review. No candidate fixes, full suite/gate, FR-08A rebind, hash recomputation, or edits to developer/main source. Temporary red mutations were restored byte-for-byte.

## Findings by severity

- **P1/P2: none found.** Both review-3 findings are closed by independently compiled controls described below.
- No additional lower-severity change request. Approval is scoped to this candidate and its precision tools; it is not approval of the future decompositions.

## Latest correction: behavior established

### Generated default arities

`lib/mix/tasks/foundry.move.ex:70-76,189-201` uses the shared `definition_arities/1` inventory for both source and target. It unwraps guarded heads and records the range from written arity minus defaults through written arity. Defaults in selected definitions remain conservatively refused by the existing unsafe-body check.

Independently compiled every original fixture with `elixirc --warnings-as-errors` before invoking the actual Mix task:

| Controlled fixture | Observed result |
|---|---|
| Retained `helper(v \\ :ok)` called as `helper()` by moved `shout/0` | Refused: local calls cross boundary; both original files byte-identical |
| Destination `shout(v \\ :existing)` versus moved `shout/0` | Refused: target definition conflicts; both files byte-identical |
| Retained guarded patterned head with two defaults, moved caller uses generated `/0` | Same cross-boundary refusal; both files unchanged |
| Destination guarded patterned head with two defaults versus moved `/1` | Same conflict refusal; both files unchanged |
| Retained separate default declaration plus implementation clauses, generated `/0` call | Same cross-boundary refusal; both files unchanged |
| Destination separate default declaration plus implementation clauses versus moved `/0` | Same conflict refusal; both files unchanged |

These cover both original review-3 reproductions, guard unwrapping, patterned arguments, multiple defaults, and the common separate default-head form. The two added committed tests detect distinct inventory uses: a stranded moved caller and an existing target function collision.

### Facade input domain and forwarding

`bin/check_move.exs:143-163` now requires one unguarded public clause, distinct unrestricted argument variables, exactly those forwarded arguments, and the remote call as the returned body. The target must still own the corresponding original facade body's compiled definition (`check_addition!/4`).

Independent warnings-as-errors compiled probes: ordinary and renamed distinct-variable heads both pass and return the hand-checked result **7** for `(10, 3)`. Constant heads, tuple patterns, duplicate variables and ignored arguments all fail comparison. Runtime controls demonstrate the rejected examples would respectively raise `FunctionClauseError` or return **-3** instead of 7. The committed controlled facade test additionally rejects a guard, wrong owner, reversed arguments, negated result and discarded result, while accepting `defdelegate`.

## Previously closed issues and full-scope review

- Bare pipes in both directions independently refuse before writes; parenthesized pipes, direct calls and captures remain covered by the focused move tests.
- Explicit/implicit/root alias conflicts and alias chains refuse unchanged in the committed tests. An independent insertion probe preserves an earlier target function's lexical alias resolution and compiles afterward.
- Independently reproduced the old wrong-owner fixture with both differently behaving owners already present at base: checker refuses; runtime controls remain `:good` versus `:wrong`.
- Reversed arguments, negated result and discarded result independently refuse (runtime values -7, -7, `:wrong`); correct delegate returns 7 and passes.
- Identical body shifted one source line passes independently.
- A real compiled Rows/Reads split using an allowed `only:` Protected import passes with and without lint.
- Actual immutable-target rename failure and immutable-source rename failure preserve both originals, including the rollback after target replacement. Both fixture directories contain exactly the original two files afterward; immutable flags were removed.
- The boundary declarations retain architecture tests as specification. Dependency additions remain locked; Sourceror and the move task are dev/test-only. The xref script uses the recorded admitted-base ceilings and approved split-edge map; focused synthetic cases reject a third cycle, thirteenth compile edge and forbidden Rows-to-Gateway edge.
- Outline fixture output is independently pinned, and malformed input exits nonzero. The docs checker enforces the 800-word front-door limit. Standing review guidance is model-neutral and calls for concrete behavior tests and mutation evidence.

The baseline graph measurement and boundary/docs red controls from review 1 were inspected as historical evidence, not rerun or represented as fresh runs here. The future split edge lists remain transitional where the approved design leaves existing facade edges. The cycle measure is strongly connected groups, matching the recorded Mix baseline.

## Checks and red controls actually run

Environment for Mix commands: `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test`.

- Focused five files: `precision_move`, `compiled_move_check`, `outline`, `xref_check`, `architecture_boundary`: **29/29 passed**, initially and again after restoring mutations and force-compiling.
- `mix compile --force --warnings-as-errors`: passed on restored candidate.
- `mix format --check-formatted`: passed.
- `elixir bin/check_docs.exs`: **0 broken links; 481/800 AGENTS.md words**.
- Default-arity red control: replace computed default count with zero, then `mix test --force test/foundry/precision_move_test.exs`: **3/5 passed, 2 failed**, both `Expected exception Mix.Error but nothing was raised`. This demonstrates both newly committed refusals detect loss of generated arities.
- Facade red control: remove the new variable-domain/distinctness conjuncts, then `mix test --force test/foundry/compiled_move_check_test.exs:169`: **0/1 passed**, because the restricted head incorrectly reports `compiled definitions match`.
- Both mutations restored exact bytes in `finally` before subsequent candidate verification.
- Real-module compiled identity controls: Gateway **126**, Maintenance **4**, ProtectedPrimitives **337** definitions pass. These establish readability of the actual compiled modules, not completion of their future split.
- Final reviewer checkout: exact named HEAD, clean Git status and `git diff --check`.

No full gate, full suite, CI job, provider session or fresh admitted-base rebuild was run.

## Separate Ponytail Review

Used the installed Ponytail Review skill on the actual diff, separately from correctness review. **Lean already. Ship.** No safe deletion or speculative abstraction identified; **net: -0 lines possible**. The generated-arity helper fixes both inventories once, and facade validation extends the existing compiled comparison. The new tests each catch a distinct plausible regression with controlled inputs and independent expected refusal.

## Reproduction artifacts and lane recording

All artifacts are outside the repository:

- `/private/tmp/ML-PRECISION-TOOLING-review-4-move-probes.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-forward-probe.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-rollback-probes.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-owner-probe.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-metadata-probe.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-import-probe.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-prior-probes.exs`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-red-defaults.txt`
- `/private/tmp/ML-PRECISION-TOOLING-review-4-red-facade.txt`

Move/rollback probes require `mix run --no-start`; other probes use `elixir` from the reviewer checkout. This reviewer will record this exact verdict with `lane review` and confirm status/log. The notes file alone is not a lane receipt.
