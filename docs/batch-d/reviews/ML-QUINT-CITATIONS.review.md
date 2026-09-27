# ML-QUINT-CITATIONS independent review

Verdict: **approved**

Reviewer: `agent:codex-gpt-6-astra/review-ML-QUINT-CITATIONS` (OpenAI GPT-6 Astra), independent of the Pi/OpenAI Sol developer.
Base: `8f3710b3a537d9a3ab6399c972076a558206e751`.
Candidate: `0cc860d9c6db6c369f804a71b24099835d206d46`.
Reviewed in detached `/private/tmp/ML-QUINT-CITATIONS-review`; candidate HEAD and clean worktree verified before and after checks.

## Findings

No blocking or nonblocking defect introduced by this delta; no correction required.

- Checked every changed citation against current function definitions and relevant operation clauses. An Elixir AST probe independently resolved all **46 distinct function/arity references** across the six scoped files, including private functions, zero-arity status accessors, and guarded clauses. Body inspection confirmed ownership in Rows, Guards, Operations, and RestartCheck, the root/child reset variants, settlement branch ordering, and reservation/attempt closure sets.
- `spec/ledger/ledger.qnt:193` correctly qualifies the historical dimension-only behavior while citing the existing `Protected.Guards.reservation_dimensions/2` (`guards.ex:487`). The current function delegates to `single_ledger/1`; preserving the dated model does not require removing that current correspondence.
- The historical pre-status-check receipt conflict at `spec/ledger/ledger.qnt:311` maps to the existing `Protected.Operations.observation_conflict?/4` and the `settle_claim` clause. Current `operations.ex:952` refuses claimed/cancelled claims first. The new historical qualifier and file-level dated-model statement preserve the distinction.
- The Q3 guard citation in `spec/fr10/README.md:166` now correctly names `Protected.Operations.settle_with_receipts/6` (`operations.ex:1283`), whose reconciliation-required branch guards entry to `reconciled_settlement/5`.
- Concept spans map to named operation clauses and helpers rather than invented functions: closed reservation statuses are checked by the `close_attempt` clause; root/child generation reset stays distinguished; the non-start discriminator and allowance retain their separate owners.
- No unresolved ambiguous mapping needs an operator decision. Existing dated-model assumptions and known divergences are retained, not adjudicated by this review.

## Scope and preservation

Exactly these six paths changed (161 insertions, 127 deletions):

- `spec/ledger/ledger.qnt`
- `spec/fr10/effects.qnt`
- `spec/core_boundary/core.qnt`
- `spec/ledger/README.md`
- `spec/fr10/README.md`
- `spec/core_boundary/README.md`

No production code, tests, dependency files, or dated evidence outside that scope changed. All three Quint files have identical non-comment content after ignoring blank lines and trailing whitespace. Zero live `PP:<number>` citations remain in the six files. Explanatory meaning, historical model provenance, design-only actions, and model limitations are preserved; TP/GW citations remain explicitly tied to the model revision.

## Independent checks

- Quint **0.32.0**: `npx --no-install @informalsystems/quint typecheck <file>` passed for **3/3** models.
- `npx --no-install @informalsystems/quint test spec/fr10/effects.qnt`: **4 passed**, 0 failed.
- `npx --no-install @informalsystems/quint test spec/core_boundary/core.qnt`: **2 passed**, 0 failed.
- `npx --no-install @informalsystems/quint test spec/ledger/ledger.qnt`: exit 0; **no witness tests defined**.
- `elixir bin/check_docs.exs`: **0 broken links**; AGENTS.md 481/800 words.
- AST citation resolution: **46/46** distinct references found with exact arities.
- Non-comment comparison: **3/3** Quint files unchanged; scope audit: **6/6** allowed paths, no extra paths.
- `git diff --check <base> <candidate>`: passed.
- Final `git status --porcelain`: empty.

Ponytail Review: Lean already. Ship. No unnecessary machinery, dependencies, or coverage-only tests.

## Limitations

This approves citation maintenance at the named candidate. The historical models are not proofs of current production behavior. No full gate, FR-08A rebind, production/provider session, exhaustive verifier, or large random simulation was run. Focused typechecks and existing witnesses plus exact executable-content preservation are sufficient for this comments-and-documentation delta. Scratch probes and this note are outside the repository; the candidate was not edited or integrated.
