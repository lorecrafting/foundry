# ML-PRECISION-TOOLING independent rereview

**Verdict: correction.** Candidate `3511fee2fc13f4c70e0ed59966d40a986edeb34b`; original candidate `2cf11a0490b4b6f65d3b27759367246aabd858dd`; admitted base `c55413fec19b113baa2f463e8dfaeb22674d8f91`. Reviewer principal: `agent:codex-gpt-6-astra/review-ML-PRECISION-TOOLING-2`.

Reviewed the correction diff and full candidate scope in detached `/private/tmp/ML-PRECISION-TOOLING-review-2`. All 17 changed paths are within the packet's admitted scope. Read the first review, standing brief, boundary rules, relevant evidence guidance and both approved designs' compiled-check requirements. No fixes to candidate code, main/developer source edits, full gate, FR-08A rebind or hash recomputation. Temporary red mutations were restored exactly; final reviewer Git status and `git diff --check` are clean.

## Findings

1. **P1 — Bare pipelines still bypass the move refusal and leave uncompilable files.** `lib/mix/tasks/foundry.move.ex:232–245`. The added pipe case requires `is_list(args)`, but valid `v |> shout` has `args == nil`. Both directions reproduce: retain `def caller(v), do: v |> shout` while moving `shout/1`, or move `def shout(v), do: v |> helper` while retaining `helper/1`. Each original fixture compiles with `elixirc --warnings-as-errors`; the move succeeds and changes both files; the resulting source or target fails compilation with `undefined function shout/1` or `undefined function helper/1`. Treat the bare pipe form consistently with `shout()` (or conservatively refuse it) before writing. The new tests exercise only the parenthesized form. This leaves first-review finding 1 partly open.

2. **P1 — Declared delegates still lose target identity and can change behavior.** `bin/check_move.exs:126–147`, especially `base_bodies` at line 127 and remote-call filtering at lines 135–142. There are two independent holes in this new validation:

   - It pools every base owner's same-name/arity body rather than binding the facade addition to its own base implementation. Reproduced base `Identity.Facade.value/0 => :good` and `Identity.Other.value/0 => :wrong`; candidate preserves the wrong body in `Other`, moves the good body to `Owner`, and declares `Identity.Facade.value/0` as `defdelegate value(), to: Identity.Other`. All source compiles with warnings as errors, there are no undeclared extra bodies, and the checker exits **0**, `compiled definitions match`. Runtime changes from **`:good` to `:wrong`**. Since the compared functions contain no calls, the ambiguity guard does not catch this. The submitted wrong-target fixture introduces its wrong implementation only in the candidate; it misses a wrong implementation already present at base.
   - One split-set remote call anywhere in a body is not proof of a delegate. With base `value(a, b), do: a - b` moved unchanged to `Probe.Owner`, declared facade wrappers calling `Owner.value(b, a)`, returning `-Owner.value(a, b)`, or discarding its result and returning `:wrong` each exit **0**. Hand-checked input `(10, 3)` changes the expected **7** to **-7** or **`:wrong`**. Check the actual forwarding clause, arguments and result, as well as the exact original owner's implementation. A genuine `defdelegate` to the correct owner passes the independent positive control.

3. **P1 — The compiled checker treats line movement as a body change.** `bin/check_move.exs:162–179`. Definitions contain clauses shaped `{meta, args, guards, body}`. `normalize/2` strips metadata from three-tuples but recursively retains the four-tuple clause's leading `[line: ..., column: ...]`. A base function `def value(v), do: v` at line 2 and the identical candidate function at line 3 (one added comment) compile cleanly, yet comparison exits **1** with `compiled definitions differ: %{extra: [{:value, 1, 1}], missing: [{:value, 1, 1}]}`. A valid two-function local-to-import split also triggers the new ambiguity guard when its helper merely changes lines. This makes ordinary approved extractions unusable, independently of the target-identity fix. Normalize clause metadata explicitly while preserving semantic data. Existing positive tests use the same function placement on both sides; their comment about differing line positions does not create such a difference.

4. **P2 — Protected import lint rejects the approved narrow import form.** `bin/check_move.exs:110–111`. The exact text regex accepts only a bare `import Foundry.DurableStore.Protected.X`. The approved design explicitly uses `only:` to avoid facade delegate/import name clashes (`docs/design/DECOMPOSE-PROTECTED-PRIMITIVES.md:75`), and its lint permits imports from `Protected.*` (lines 218–220). Independently compiled a small correct Rows/Reads split using `import Foundry.DurableStore.Protected.Rows, only: [row: 1]`, aligning source lines to isolate finding 3. The compiled comparison exits **0** without lint and **1**, `forbidden split directive`, with required lint enabled. Permit structurally valid narrowed imports from the allowed modules without weakening the alias/require restrictions. The current lint test contains only a forbidden-alias negative control.

## Disposition of the first review

| First finding | Rereview evidence |
|---|---|
| Piped local callers | Parenthesized retained and moved callers now refuse unchanged; bare pipes remain unsafe (finding 1). |
| Alias shadowing/chains | The original unaliased-root shadow, explicit alias conflict, target-shadowed alias root and alias chain cases all refuse before writes in the focused suite. Conservative alias-chain refusal is within the documented limit. |
| Wrong split-set target | The original undeclared changed-call fixture is rejected; duplicate additions are rejected and a correct facade delegate is accepted. Declared delegates remain unsound (finding 2). |
| Destination failure | Missing-parent test passes. Independent actual target-rename failure and source-rename failure both preserve source and existing target byte-for-byte and remove staging files. Source-failure probe exercises the rollback branch. |
| Formatting | `MIX_ENV=test mix format --check-formatted` exits 0. |
| Model-specific standing brief | `docs/AGENT-BRIEF.md:68` now requires a fresh agent and distinct principal without a fixed model. Closed for this scoped document. |

## Verification actually run

Commands ran from the detached reviewer checkout, using `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test` where applicable.

- Focused suite: `mix test test/foundry/{precision_move,compiled_move_check,outline,xref_check,architecture_boundary}_test.exs`: **24/24 passed**. After restoring both red mutations, the same five files with `mix test --force` again passed **24/24**.
- `mix compile --force --warnings-as-errors`: passed on the unmodified candidate.
- `mix format --check-formatted` in test environment: passed.
- `elixir bin/check_docs.exs`: passed, **0 broken links; 481/800 AGENTS.md words**.
- Ambiguity-guard red mutation: changed `MapSet.size(disputed) > 0` to `< 0`; compiled checker tests failed **1/2 passed**, `assert status != 0`, actual `0`. Restored exact bytes.
- Pipe-arity red mutation: changed `length(args) + 1` to `+ 0`; forced move tests failed **2/3 passed**, `Expected exception Mix.Error but nothing was raised`. Restored exact bytes.
- Real-module identity comparisons pass: Gateway **126** and Maintenance **4** definitions; ProtectedPrimitives **337**. These controls establish that unchanged compiled modules can be read, not that a real extraction passes; finding 3 supplies the missing movement control.
- Actual filesystem-failure probes used the macOS immutable flag only on reviewer-owned fixture files. Blocking target rename preserved both originals; blocking source rename after target replacement restored the original target. Both directories contained only the two original filenames afterward; immutable flags were removed in `after` cleanup.

Reproducible reviewer artifacts (all outside the repo):

- `/private/tmp/ML-PRECISION-TOOLING-review-2-move-probes.exs` — `mix run --no-start` for bare retained/moved pipes and the two rename failures. It also demonstrates the task's manual-rewrite limitation for explicitly qualified self calls; that observation is not counted as an additional finding.
- `/private/tmp/ML-PRECISION-TOOLING-review-2-owner-probe.exs` — `elixir`, preserving both original implementations while misdirecting the declared facade.
- `/private/tmp/ML-PRECISION-TOOLING-review-2-probes.exs` — `elixir`, correct forwarding, changed arguments/results, real-module identity checks.
- `/private/tmp/ML-PRECISION-TOOLING-review-2-metadata-probe.exs` — `elixir`, unchanged body shifted one line.
- `/private/tmp/ML-PRECISION-TOOLING-review-2-import-probe.exs` — `elixir`, compiled-good narrow import refused by lint.
- Red-control transcripts: `/private/tmp/ML-PRECISION-TOOLING-review-2-ambiguous-call-guard.txt` and `/private/tmp/ML-PRECISION-TOOLING-review-2-pipe-arity-guard.txt`.

## Test quality and complexity pass

The added cases target plausible distinct failures: both directions of a pipe boundary; explicit, implicit and root alias shadowing; alias-chain resolution; filesystem preflight; split-target confusion; duplicate declarations; and correct/wrong facade forwarding. They use controlled inputs and independent expected behavior. There are no coverage-only tests to delete. The consolidated checker test would be easier to diagnose as separate behaviors, but its organization is not an acceptance defect.

Missing controls are substantive: bare pipes; wrong owner already present at base; exact forwarding semantics; changed line/column metadata; allowed `only:` import. The missing-directory test checks preflight rather than rollback; the independent probes above establish both actual existing-target failure branches for this candidate.

Applied the installed Ponytail Review skill separately to the actual diff: no speculative subsystem or safe line deletion identified. Complexity-only result: “Lean already. Ship.” **net: -0 lines possible.** That narrow result does not override the correctness verdict.

No full suite/gate, CI, provider session, actual Gateway/Protected decomposition, production operation or fresh baseline graph measurement was performed. The initial review's baseline/red evidence remains historical; it is not claimed as rerun here. This candidate requires correction before acceptance.
