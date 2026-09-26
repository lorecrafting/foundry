# ML-DECOMPOSE-PP independent review

**Verdict: approved.** Candidate `364008a509ea8d9dbba4efff512c40f304e6ed52`; admitted base `aa19b69cb3a545fc8db7f9e6be0d8062249f217d`; reviewer `agent:codex-gpt-6-astra/review-ML-DECOMPOSE-PP`.

## Findings and scope

No blocking correctness finding. Detached `/private/tmp/ML-DECOMPOSE-PP-review` was clean at the exact candidate before and after review. The range contains exactly two commits (`d9083d0`, `364008a`), 17 paths, 7,995 insertions and 7,850 deletions; every path is within the packet scope. Operations remains whole, the facade remains, and no runtime caller, schema, dependency, pin provider or rebind artifact changed. Read the packet, developer and reviewer briefs, repository rules, approved PP design and all three design reviews, Q17/Q18, and bounded move-checker review 5.

**Low priority, documentation:** `spec/core_boundary/README.md:82–84` and `:151` retain shorthand old PP line references (`:1347-1356`, `:1006`, `:3435-3470`, `:3211-3224`) alongside the newly converted module/function references. These are inherited citations, not changed behavior. Finish their conversion during the planned citation pass. All explicit new `Protected.Module.function/arity` citations were checked against candidate compiled definitions. Link checking reports zero broken links. Historical Quint source citations remain deferred as authorized.

## Mechanical and boundary evidence

- Fresh candidate compilation and separate force compilation of the clean exact base, with `MIX_ENV=test`, shared dependency directory only. Candidate force compile with `--warnings-as-errors` also passed.
- Ran `/private/tmp/foundry-integ-C2/bin/check_move.exs` against these base and candidate BEAM directories with all seven named facade delegates, the three attribute accessors, and `--lint-protected lib/foundry/durable_store/protected/*.ex`. **337 base definitions match 347 candidate definitions**, including generated arities. Counts: facade 24, Rows 68, Guards 29, ReadSet 25, Reads 51, TransitionReplay 49, Operations 33, RestartCheck 68. Output: `/private/tmp/ML-DECOMPOSE-PP-review-move.txt`. The seven delegate targets match their original bodies; the accessors return the original vocabulary attributes. Compiler-resolved imports/aliases match and the source lint passes.
- Ran integrated `check_xref.exs`: **2/2 cycles, 18/18 compile edges, zero forbidden split edges**. Independently inspected actual graph `/private/tmp/ML-DECOMPOSE-PP-review-xref.json` against the closed design table, including external Core targets: Rows has only Database/Encoding; Guards/ReadSet/Reads/TransitionReplay depend only on Rows within the split; Operations on Guards/Rows; RestartCheck on Guards/Rows/TransitionReplay and the existing Database/Encoding/TransitionPlan/Gateway seam. Facade has only its prescribed six split dependencies and Database. Thus approval does not rely on the checker's temporarily broader facade allowance. `mix xref callers Foundry.DurableStore.ProtectedPrimitives` confirms existing Core, lane and pin-provider callers still enter through the facade.
- Inspected `git diff --color-moved=plain --color-moved-ws=allow-indentation-change` (saved as `/private/tmp/ML-DECOMPOSE-PP-review-color-moved.diff`) and the nonmove delta. The seven-module ownership table agrees with the actual placements. The only implementation additions are module/import scaffolding, accessors and delegates, and rule 13 with role-site relocation.
- Literal multisets match base: 11 digest-tag sites, three `Database.transaction` sites, one `System.halt`, 54 literal reject sites and one quarantine site. These counts supplement the compiled-body comparison.

## Independent behavior traces

- `ProtectedPrimitives.execute/5` still performs identity/normalization and command lookup before applying; `execute_new/6` holds apply/result/mirror writes in one transaction. An ordinary semantic rejection rolls back and records its refusal in a second transaction. Quarantine commits its changed state with a rejected result. `persist_committed_result/8` inserts `root_commands`, then its `durable_operations` mirror, then invokes the before-commit fault. After-commit-before-reply injection remains after the transaction. `execute_in_transaction/4` opens no transaction of its own.
- `Operations.apply_operation/2` create-effect still checks attempt, predecessor, policy/control revisions, independence, non-start allowance, reservations and leases before inserting effect, activating reservations, and inserting pending leases, in that order. Its specific guard errors remain semantic refusals. Root reset/close still revokes unissued reservations before retiring available units. Settlement still distinguishes exact receipt replay, quarantine, duplicate observation, stale unknown, reconciliation and first settlement in the same order.
- Command digest still binds actor and request in Rows; receipt digest still binds claim, request, outcome, proof and payload, excluding receipt id. RestartCheck recalculates the same digests. `RestartCheck.validate/1` retains blob, history, pointer, inbox, ledger, reservation, binding and provenance ordering. Its authority provenance check calls both TransitionReplay validators. Typed replay processes ordered command history, skips ordinary rejected transitions, and replays rejected conflicting receipts as quarantine before comparing current rows.
- Reviewed the direct mapper capture inputs against the approved bounded checker contract. Imported `public_ledger/1` captures consume lists returned by `subtree_ledgers/3`; imported `public_reservation/1` consumes lists returned by activation or reservation loaders; imported `reservation_from_row/1` consumes SQL row lists; imported `public_receipt/1` consumes the list accumulator returned by `receipt_rows/3`. Database.query uses Sqlite3.fetch_all, not a caller-provided Enumerable. Retained mapper targets similarly operate on query lists, guarded decoded lists, or Map.values lists. No changed capture is handed a custom Enumerable or exposed for caller introspection along these routes. This establishes the real input assumption; the checker itself only proves bounded invocation equivalence.

## Checks actually run

From the reviewer checkout, with `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test`:

- `mix test test/foundry/durable_store test/foundry/architecture_boundary_test.exs test/foundry/workflow/decide_e2e_test.exs test/foundry/manual_lane`: **403 passed**, 122.5 seconds. Includes the 150-sequence reopen property, restart/corruption probes, atomic bundles, refusal/independence/quarantine checks, fault/storage checks and lane consumers. Output `/private/tmp/ML-DECOMPOSE-PP-review-tests.txt`. Relational oracle: 1,286 accepted transitions; no violations in witnessed families, with phase_agreement_nil and receipt_custody explicitly unwitnessed in this focused selection.
- `mix test test/foundry/repair/fr08a_protected_boundary_test.exs`: **2 passed, 2 expected failures**, source/BEAM identity mismatch and frozen artifact mismatch before operator rebind. Output `/private/tmp/ML-DECOMPOSE-PP-review-pin-test.txt`.
- `mix compile --force --warnings-as-errors`, `mix format --check-formatted`, `git diff --check aa19b69..HEAD`, and `elixir bin/check_docs.exs`: passed; docs **0 broken links**.

### Rule 13 red controls

All mutations were confined to an archived scratch copy `/private/tmp/ML-DECOMPOSE-PP-review-red`; candidate/integration sources were never edited. Loaded the actual architecture test with Mix and ExUnit started.

1. Added `alias Foundry.DurableStore.Protected.Rows, as: R` and `R.update_ledger/3` under `lib/foundry/manual_lane/reviewer_leak.ex`: **14/15 passed, exactly rule 13 failed**, reporting alias at line 2 and writer call at line 3. Output `/private/tmp/ML-DECOMPOSE-PP-review-rule13-red.txt`.
2. Removed the leak and inserted all seven module tuples into the real provider's `@api_identity`: **15 passed**. Output `/private/tmp/ML-DECOMPOSE-PP-review-rule13-pin.txt`.
3. Kept those tuples and added an alias and writer function elsewhere in the pin provider: **14/15 passed, exactly rule 13 failed**, reporting provider alias/function sites. Output `/private/tmp/ML-DECOMPOSE-PP-review-rule13-provider-call.txt`.

An initial scratch invocation omitted Mix startup and also failed rule 6; it was discarded and rerun with Mix initialized, yielding the exact single-failure controls above. The committed two-test addition is small and covers the new reference restriction plus alias resolution. The scratch controls exercise the actual reject filter and its narrowly located exception. As designed, this is a static module-reference fence using the existing scanner, not runtime capability isolation or arbitrary dynamic-call analysis.

## Separate Ponytail Review

**Lean already. Ship.** Complexity-only review of the actual delta found no safe deletion within the approved scope. Reuses the existing scanner, move checker and xref machinery; adds no dependency or alternate framework. The retained facade and whole Operations module are explicit Q18 requirements, not speculative abstractions.

## Limits and receipt

Approval is for this exact move candidate. It does not certify FR-08A readiness before the operator adds seven pins and performs the integrated rebind. No full gate, provider session, integration, rebind or Quint execution ran. Existing semantic issues described by the contract/model documents were not repaired by this move. Runtime hot-code replacement, capture identity/stack introspection and arbitrary custom Enumerable behavior are outside the bounded equivalence claim.

The reviewer records this verdict through the lane using this notes file, then confirms the receipt and ticket status/log. A notes file alone is not a completed review.
