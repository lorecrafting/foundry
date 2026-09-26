# ML-PRECISION-TOOLING independent review 3

**Verdict: correction.** Exact candidate `3d3ec7345148ea36f0d74ba3126ced495784cdfd`; admitted base `c55413fec19b113baa2f463e8dfaeb22674d8f91`; previous candidate `3511fee2fc13f4c70e0ed59966d40a986edeb34b`. Reviewer principal: `agent:codex-gpt-6-astra/review-ML-PRECISION-TOOLING-3`.

Reviewed the full base-to-candidate diff and latest correction in detached `/private/tmp/ML-PRECISION-TOOLING-review-3`. All 17 changed paths are inside the packet's scope. Read both prior reviews, standing brief, boundary/evidence guidance and both approved designs' compiled-move requirements. No candidate fixes, full suite/gate, FR-08A rebind, hash recomputation, or edits in the developer/main source checkout. Temporary mutations were restored byte-for-byte; final reviewer Git status and `git diff --check` are clean.

## Findings

1. **P1 — Default-generated arities bypass both cross-boundary and destination-conflict checks.** `lib/mix/tasks/foundry.move.ex:70–88,180–184`. `definition/1` records only the number of arguments written in a head. The retained source and destination may contain defaults even though defaults inside selected definitions are refused. Two independently compiled, valid-input examples are accepted and change both files:

   - Source `def helper(v \\ :ok), do: v; def shout, do: helper()`, moving `shout/0` into an empty target. The source inventory contains `helper/1` but omits generated `helper/0`. The resulting target fails compilation with **undefined function helper/0**.
   - Source `def shout, do: :moved`, destination `def shout(v \\ :existing), do: v`, moving `shout/0`. The destination inventory omits its generated `shout/0`. The resulting target fails compilation with **def shout/0 conflicts with defaults from shout/1**.

   Both original source/target pairs compile with `elixirc --warnings-as-errors` (exit 0); both moves succeed; both resulting compilations exit 1. Account for every generated arity in the shared inventory or conservatively refuse affected defaults before writing. Add controlled cases that verify refusal leaves both originals unchanged. This is a sibling of the original local-call safety defect, outside the newly added bare-pipe cases.

2. **P1 — The declared-delegate checker accepts a facade that narrows its input domain.** `bin/check_move.exs:151–156`. Comparing head arguments to forwarded expressions does not establish that the head accepts arbitrary arguments. Reproduction:

   ```elixir
   # Base
   defmodule Head.Facade do
     def value(a, b), do: a - b
   end
   # Candidate
   defmodule Head.Owner do
     def value(a, b), do: a - b
   end
   defmodule Head.Facade do
     def value(0, b), do: Head.Owner.value(0, b)
   end
   ```

   Both revisions compile with warnings as errors. `elixir bin/check_move.exs BASE CANDIDATE Head.Facade Head.Facade,Head.Owner Head.Facade.value/2` exits **0**, `compiled definitions match`. The original `value(10, 3)` returns **7**; the candidate raises **FunctionClauseError**. The candidate head and call both contain the same constant, satisfying the new equality guard. Require an unrestricted forwarding head with distinct variables (and unchanged forwarding/result), or otherwise prove the accepted argument domain unchanged. Preserve the positive ordinary `defdelegate` case. The existing owner/argument/result test never changes the head's accepted domain.

## Prior-review disposition and independent positive checks

| Prior issue | Evidence on this candidate |
|---|---|
| Bare pipelines, both directions | Independently compiled originals; both moves now raise `local calls cross the move boundary`, both files byte-identical. Parenthesized pipelines, captures and direct calls also pass committed refusal tests. |
| Wrong declared owner already present at base | Prior three-owner fixture now exits 1 with `declared delegate target differs`; runtime wrong-owner value remains independently observed as `:wrong` versus base `:good`. |
| Changed forwarding arguments/result | Correct delegate exits 0 and returns 7. Reversed arguments, negated result and discarded result each exit 1; runtime controls return -7, -7 and `:wrong`. The additional head-domain hole is finding 2. |
| Clause line metadata | Independently shifted unchanged function now exits 0. |
| Allowed narrow Protected import | Real two-function local-to-`Rows`/`Reads` split compiles with warnings as errors and passes comparison both with and without lint; the source uses `only: [row: 1]`. |
| Alias conflicts/chains | All four committed explicit/implicit/root shadow and chain cases refuse unchanged. An additional alias-insertion probe preserves the earlier target function's lexical resolution and compiles; it is not a finding. |
| Pair-write failure | Actual immutable target and immutable source rename failures preserve both original files exactly, including rollback after target replacement. Both directories contain only the original two files; immutable flags removed. Missing-parent preflight also passes. |
| Formatting, standing brief | Formatting check passes. Fresh distinct-principal review wording remains model-neutral in the scoped agent brief. |

Compiled identity comparisons also pass for Gateway **126**, Maintenance **4**, ProtectedPrimitives **337** definitions. These are identity controls, not proof of the future full decomposition. One initial Protected identity read overlapped reviewer force-compilation and saw a transient missing BEAM; it was rerun after compilation completed and passed. No candidate defect is inferred from that reviewer scheduling error.

## Checks and red controls actually run

Commands ran in the detached reviewer checkout with `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test` where applicable.

- Five focused files (`precision_move`, `compiled_move_check`, `outline`, `xref_check`, `architecture_boundary`): **27/27 passed**, initially and again with `mix test --force` after restoring every mutation.
- `mix compile --force --warnings-as-errors`: passed on restored candidate.
- `mix format --check-formatted`: passed.
- `elixir bin/check_docs.exs`: **0 broken links; 481/800 AGENTS.md words**.
- Bare-pipe guard mutation (remove nil-argument handling): **0/1 passed**, `Expected exception Mix.Error but nothing was raised`.
- Declared-forwarding validation neutralized: **0/1 passed**, wrong-owner acceptance produced `compiled definitions match` and failed the expected-status assertion.
- Clause-metadata normalization removed: **0/1 passed**, unchanged shifted function produced `compiled definitions differ`.
- Narrow-import regex allowance removed: **0/1 passed**, valid `only:` import produced `forbidden split directive`.

Every mutation was an exact-string edit in the reviewer worktree, restored in `finally`. The forwarding mutation was initially aimed at line 166, which selected the preceding line-shift test and stayed green; corrected targeting at line 169 selected the intended test and produced the red result above. The final saved forwarding transcript contains that intended red run. The developer reported four red mutations but supplied no transcript paths; those reports are not represented as independently inspected artifacts. The four reviewer runs above establish the corrections' test sensitivity directly.

The focused xref tests exercise the live graph and independent synthetic third-cycle, thirteenth-compile-edge and forbidden Rows-to-Gateway fixtures. The admitted-base measurement and boundary/docs red evidence from review 1 were read as historical evidence, not rerun here. No fresh baseline graph build, full gate, CI, provider session or production operation was run.

## Test quality and Ponytail Review

The new tests exercise distinct useful behavior: line movement, exact owner/forwarding, allowed narrow imports and both bare-pipe directions. Their expected exit status and literal behavior are independent of the implementation. The import fixture inside the committed test only parses source, but the independent compiled Rows/Reads fixture supplies the missing integration control. The default-generated arities and restricted facade-head cases above are substantive missing cases, not coverage-only requests. Earlier outline, xref, move and changed-body tests remain useful.

Separate complexity-only pass using the installed Ponytail Review skill: **Lean already. Ship.** No safe deletion or speculative abstraction identified; **net: -0 lines possible**. This complexity-only assessment does not override the correctness verdict.

## Reproduction artifacts

All paths are outside the repository. Run Elixir scripts from the reviewer checkout; the move and rollback scripts require `mix run --no-start` with the environment above.

- `/private/tmp/ML-PRECISION-TOOLING-review-3-move-probes.exs`: both default-arity failures, both bare-pipe refusals, and lexical alias positive probe.
- `/private/tmp/ML-PRECISION-TOOLING-review-3-forward-probe.exs`: correct unrestricted forwarding and accepted restricted-head failure, with runtime values.
- `/private/tmp/ML-PRECISION-TOOLING-review-3-prior-probes.exs`: argument/result controls and real identity checks.
- `/private/tmp/ML-PRECISION-TOOLING-review-3-owner-probe.exs`, `...-metadata-probe.exs`, `...-import-probe.exs`: prior independent repros rerun against this candidate with reviewer-owned scratch paths.
- `/private/tmp/ML-PRECISION-TOOLING-review-3-rollback-probes.exs`: actual target/source rename failures.
- `/private/tmp/ML-PRECISION-TOOLING-review-3-red-{bare-pipe,forwarding,clause-meta,narrow-import}.txt`: four independent red transcripts.

The candidate requires correction before acceptance. This review is to be recorded by this principal through `lane review`, then confirmed through lane status/log; the notes alone are not a lane receipt.
