# ML-PRECISION-TOOLING independent review

**Verdict: correction.** Candidate `2cf11a0490b4b6f65d3b27759367246aabd858dd`; admitted base `c55413fec19b113baa2f463e8dfaeb22674d8f91`. Reviewer: `agent:codex-gpt-6-astra/review-ML-PRECISION-TOOLING`. Reviewed the complete two-commit diff and approved split-design move-check sections in detached `/private/tmp/ML-PRECISION-TOOLING-review`. All 17 changed paths fall within admitted scope. No candidate fixes, main edits, gate run, FR-08A rebind or hash recomputation.

## Findings

1. **P1 — Piped local callers bypass the pre-write refusal.** `lib/mix/tasks/foundry.move.ex:206–219` counts the explicit argument list, ignoring the argument supplied by `|>`. Valid source `def caller(v), do: v |> shout()` plus `def shout(v), do: v` is accepted when moving `shout/1`. The task writes both files, leaving the source uncompilable: `undefined function shout/1`. The same arity problem applies to a moved body piping into a retained helper. Account for pipe expansion or refuse it conservatively before writing; test the files remain unchanged. Existing direct-call and wrapped-arity capture controls do not cover this form.

2. **P1 — Alias repair does not preserve lexical resolution.** `lib/mix/tasks/foundry.move.ex:88–109,242–250`. Two independent valid-input examples are accepted and written: (a) moving `def shout(v), do: String.upcase(v)` into a target with `alias List, as: String` changes the target to `List.upcase/1`; (b) source `alias String, as: Text; alias Text, as: More; def shout(v), do: More.upcase(v)` carries only `alias Text, as: More`, losing the alias chain and calling nonexistent `Text.upcase/1`. Current conflict detection considers only aliases explicitly declared in the source and stores unresolved alias syntax. Resolve relevant aliases in lexical order, including unaliased roots affected by target aliases, or refuse these forms before writing. Parsing the resulting syntax is insufficient.

3. **P1 — Compiled checker approves a changed split-set call target.** `bin/check_move.exs:91–101` erases the owner from every definition and every split-set remote call without checking the actual target implementation. Reproduced with warnings-as-errors compilation and no declared additions:

   ```elixir
   # Base
   defmodule Check.A do
     def entry, do: helper()
     def helper, do: :good
   end
   defmodule Check.C do
     def helper, do: :wrong
   end
   # Candidate
   defmodule Check.B do
     def entry, do: Check.C.helper()
     def helper, do: :good
   end
   defmodule Check.C do
     def helper, do: :wrong
   end
   ```

   `elixir bin/check_move.exs BASE_EBIN CANDIDATE_EBIN Check.A,Check.C Check.B,Check.C` exits **0**, `compiled definitions match`, although `Check.A.entry()` returns `:good` and `Check.B.entry()` returns `:wrong`. The design's normalization needs an accompanying target/ownership check, or conservative rejection of ambiguous function keys. The single altered-body test only changes an outside-split String call and cannot detect this false assurance. Also, the additions-length comparison at line 36 is tautological: `Enum.map` preserves length, so duplicate declarations are not validated by it.

4. **P1 — Destination write failure leaves the source destructively changed.** `lib/mix/tasks/foundry.move.ex:131–135`. With a valid one-function source and a new target under a nonexistent parent directory, the task removes the source function, then raises `File.Error` writing the target. Observed `source_changed=true target_exists=false`. A common path typo loses the only copy from the working source. Validate destination prerequisites before changing the source and preserve/restore both originals if committing the pair fails. Add a controlled destination-failure case; syntax reparsing does not exercise filesystem failure.

5. **P2 — Required formatting check fails at the candidate.** `test/foundry/compiled_move_check_test.exs:37`. `MIX_ENV=test mix format --check-formatted` exits **1** and names this file; the `System.cmd` options/closing parenthesis need the formatter's normal multiline layout. The developer's reported format pass does not describe this candidate.

6. **P2 — Standing review wording remains model-specific.** `docs/AGENT-BRIEF.md:68` still mandates “a different model (Fable)”. The requested durable model-neutral review guidance is incomplete; keep freshness/independence, remove the stale fixed model. The new self-review and lean-test clauses themselves are clear.

## Reproduction artifacts

Run from the detached checkout, with `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test`:

- `mix run --no-start /private/tmp/ML-PRECISION-TOOLING-probes.exs` reproduces the pipe and both alias failures. Its additional bare-zero-arity fixture was excluded from findings because the original syntax is already invalid under the installed Elixir version.
- `mix run --no-start /private/tmp/ML-PRECISION-TOOLING-checker-probes.exs` independently compiles the base/candidate above, prints checker status and both runtime values, and reproduces the target-write failure. Remove its generated `missing_parent` directory first only if a later investigation creates it; it did not exist during this review.
- Minimal move invocation for each fixture: `mix foundry.move --from SOURCE.ex --to TARGET.ex --module Probe.Target --functions shout/1`; use `hello/0` and `WriteProbe.Target` for the destination-failure source `defmodule WriteProbe.Source do; def hello, do: :ok; end`.

## Verification and test impact

- Focused five-file suite (`precision_move`, `compiled_move_check`, `outline`, `xref_check`, existing `architecture_boundary`) passed **22/22**, both initially and after restoring red controls. No full suite/gate was run.
- Final `mix compile --force --warnings-as-errors` passed. Docs check passed: **0 broken links, 481/800 words**. Format check failed as finding 5.
- Boundary red control: added a temporary `Foundry.DurableStore.ReviewBoundaryProbe` calling the existing `Foundry.Workflow.Kernel.decide/3`. Compilation exited **1**, specifically `references from Foundry.DurableStore to Foundry.Workflow are not allowed`. Removed the probe and compilation passed.
- Critical checker mutation: disabled the definition inequality at line 36; its focused test failed **0/1 passed**, `assert status != 0`, actual `0`. Restored exact source.
- Critical refusal mutation: replaced the cross-boundary `Mix.raise` with `:ok`; move tests failed **1/2 passed**, `Expected exception Mix.Error but nothing was raised`. Restored exact source. The wrapped-arity `&shout/1` case passes on the restored implementation.
- Docs red control: appended 801 words; checker exited **1**, **1282/800**. Restored exact source.
- Independently compiled an archive of the true admitted base inside reviewer-owned `.review-base`: `mix xref graph --format cycles` reported **2** groups; `--label compile --format stats` reported **12** compile edges. Removed the entire reviewer-created scratch directory afterward. Current graph and synthetic third-cycle, thirteenth-compile-edge, forbidden Rows→Gateway cases passed their focused assertions.
- Additional hand-checked outline fixture correctly reported two `f/1` clauses at **2–2** and **3–5**, macro `m/1` at **6–8**, and module at **1–9**. A multiline keyword-body function also ended at the correct line.

The nine new tests each have a distinct useful behavioral purpose; none merely raises coverage or tests a library in isolation:

| New test | Distinct regression caught; assessment |
|---|---|
| Move success | Moved callable and explicit `as:` alias lost; useful, but does not assert carried docs/specs |
| Move refusal | Direct stranded call, wrapped-arity capture, explicit alias conflict mutate files; useful consolidated cases, misses findings 1/2/4 |
| Compiled comparison | Outside-split body alteration accepted and forbidden alias lint ignored; useful, misses target-identity finding 3 and declared additions |
| Outline shape | Nested names, guard arity, macro spans rendered incorrectly; hand-written expected output is independent |
| Outline malformed | Malformed input returns success/partial output; appropriate CLI contract check |
| Xref current graph | Actual project graph exceeds ceilings or introduces forbidden known split edge; integration case |
| Xref third cycle | Cycle ceiling ignored independently of compile edges |
| Xref forbidden edge | Rows→Gateway layering violation ignored independently of global counts |
| Xref thirteenth edge | Compile ceiling ignored independently of cycles |

Existing architecture tests do not substitute for these new tool behaviors. The move task documents its conservative self-contained-group limit and manual caller rewrites; this can support bounded extractions, but the reproduced unsafe acceptances violate that limit. Sourceror is dev/test-only and the task definition is gated accordingly. New tests use `System.tmp_dir!()`; no added hardcoded macOS temporary path was found. Xref enforces the named future split paths, but retains explicitly transitional facade edges to Gateway/TransitionPlan; those must tighten when the facade split lands. The global cycle metric is strongly connected groups, matching Mix's measured baseline, not every individual cycle.

Ponytail-only observation: `bin/check_move.exs:L36: delete: impossible additions-length predicate after Enum.map/2. Nothing replaces this predicate (duplicate-declaration validation is a separate correctness need).` Net: **0 whole lines**, one dead expression. No speculative subsystem merits deletion.

Final reviewer checkout is clean; developer checkout and main source were untouched. This review does not certify the future decompositions or provider/CI execution.
