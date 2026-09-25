approved

Reviewer: a fresh Fable 5.1 agent (`claude-fable-5-1`), read-only, not the author and not a fork; run outside the lane on 2026-09-25.

Reviewed: /private/tmp/foundry-front-door-review at 26abc84 (correction of a076625, base b43dc0f). Read-only; nothing edited in the checkout. Diff read in full (13 files: 11 doc edits plus the two review records added).

## Front-door review 1, F1–F11

| Finding | Fixed? | Evidence |
|---|---|---|
| F1 `lane log` and pre-Core refusals (CONCEPTS.md:134-139) | yes | `Log.trail/2` reads only `atomic_bundles`/`root_commands` rows with `disposition != 'accepted'` (lib/foundry/manual_lane/log.ex:25-28, 42-60). `wrong_source_phase` is a kernel reject before submit (lib/foundry/workflow/kernel/shared.ex:37; backend.ex:120 `with {:ok, decision} <- WorkflowKernel.decide` falls through on `{:reject, _}`); `candidate_mismatch` at backend.ex:278-281 and cli.ex:392 before any write; `git_evidence` at cli.ex:171/497-500 before `Backend.deliver`. Every lane command, refused or not, is appended to the operator log by `observe/4` → `Log.operator` (cli.ex:74-75, 550-558). "a lost revision race" = `revision_conflict` reason code recorded by Core (gateway.ex:1161, 1570-1571). LANE-RUNBOOK.md:224-226 took the same qualifier. |
| F2 README.md:39 reconciliation overclaim | yes | Wording is the finding's. FR-10 Blocked (docs/REPAIR-PLAN.md:526); `unknown` permanent, units held, ticket abandoned (LANE-RUNBOOK.md:145); `settle/6 :unknown` is a `settle_root` with `"outcome" => "unknown"` and no retry path (backend.ex:334-341, 359-381). |
| F3 CONCEPTS.md:96-101 command identity | yes | Caller-supplied id: gateway.ex:450 `normalized_command["command_id"]`; lane ids from state: backend.ex:14-15 moduledoc, `issue/…` at backend.ex:100-101 (`ticket/role/launch-count/principal`). Fingerprint = digest of canonical `{actor_id, command}` (gateway.ex:1419-1430 `prepare_command`). `existing/4` returns stored result on `{actor_id, digest}` match, else `:idempotency_conflict` (gateway.ex:1766-1783); the lane handles that atom at backend.ex:132. |
| F4 CONCEPTS.md:164 "pure" | yes | "pure" dropped. `resolve/5` defaults `now` from `System.system_time/1` (lib/foundry/launch_eligibility.ex:52-53); `Quota.Fallback` reads the clock (fallback.ex:107, 122, 133). No callers of either module outside its own file (`grep -rln` over lib/ with quoted globs: none). |
| F5 README.md:53, 55 diagram syntax | yes | `lane submit --candidate <sha> --checkout <dir>` / `lane review --verdict approved\|correction\|rejected` match `@commands` and `@verdicts` (cli.ex:30-33, 46-48, 62). The finding accepted the ID-less arrow form. |
| F6 CONCEPTS.md:104 "include" | yes | `@operation_types` also holds `set_control`, `append_inbox`, `seal_inbox`, `close_generation`, `close_attempt` (protected_primitives.ex:7). |
| F7 CONCEPTS.md:186 "Every code change" | yes | 26abc84 itself is an operator doc commit outside the lane, so the qualifier is needed and true. |
| F8 docs/README.md layer 4 row | yes | Row removed from layer 4 (docs/README.md:91-95), added to layer 5 (docs/README.md:104). Layer 5 = "dated records ... code, tests or live docs cite them" (docs/README.md:97-100); the doc carries a dated status line (design/bounded-effect-query-design.md:5) and OBSERVABILITY.md:25 cites it. |
| F9 check_docs description | yes | AGENTS.md:47 and docs/README.md:120-121 now name `#anchor`; bin/check_docs.exs:2, 44-52 checks fragments against headings/ids. |
| F10 bare Pramāṇa SHA | yes | PRODUCT.md:7, and the same line in RESEARCH.md:10 and VALIDATION.md:6 (both had the identical defect; consistent). README.md:154-156 rule now inapplicable, so the qualifier is what makes the SHA attributable. |
| F11 DURABLE-STORE.md:6-7 | yes | Reviewer's wording adopted verbatim. `lane log` is read-only SQLite (log.ex:31-33); `settle_root` is a root command to the gateway without `decide/3` (backend.ex:359-381). See N2 below for a residual looseness the finding's own wording carries. |

## CONTRACT-R3 review, F1–F5

| Finding | Folded? | Evidence |
|---|---|---|
| F1 define "observation" | yes | WORKFLOW-CONTRACT.md:116-122; the review's sentence with em dashes rendered as parentheses. Cited uses at :330, :423-424, :432, :442 of a076625 are untouched (now +14). |
| F2 R1/R4 citations | yes | :123-130. Each quotation located: "requires verified process/session termination or proved non-start" (R4 lifecycle row, :456); "controller exit/receipt reason_code ... not an agent's assertion" (:572-574); "last accepted sequence"/"late evidence" (:524-527), R4.08.f2 (:540), R4.19.f2 (:551); "missing pane alone is insufficient" (:421); "observing expiry alone proves neither termination nor non-start" (:415). The sentence split ("Stating it once here...") does not change meaning. |
| F3 enforcement split | yes | :137-141, the review's text. `require_reviewer_stream_sealed/1` (review.ex:288, 375); Core-side receipt/claim binding and root-derived-fields rule unchanged. |
| F4 header | yes | :5-11 records the review, verdict, date and link; "no candidate may cite" caveat dropped. "its four wording changes" = F1, F2, F3 and the F5 tweak. |
| F5 disposition tweak | yes | :144-145 "(`review_recorded` records it; only `attempt_settled` terminalises)". |
| F6 (info) | n/a | Not folded; not asked. |

- No R1–R5 decision changed: the diff touches only :2-13 (header) and :112-147 (R3 paragraph); every table row is byte-identical.
- R4 row tables: `mix test test/foundry/workflow/r4_coverage_test.exs test/foundry/workflow/r4_guard_reachability_test.exs` → 54 passed, 0 failures, exit 0 (`R4Rows` parses the from-cells out of the live contract; a changed row fails by name).

## Q14

DOGFOOD-LOG.md:198 states it as **Open**, attributes the observation to R3 review F2, names the kernel guard (`review.ex:375` `require_reviewer_stream_sealed/1`) and R4's outcome-side wording (R4.16.o1/R4.17.o2 "Close/seal reviewer", :548-549), and decides nothing. Accurate. The Q13 row's appended sentence (:197) is also accurate: both reviews exist at the linked paths with the verdicts stated.

## New findings

**N1 (low, attribution) WORKFLOW-CONTRACT.md:9** — "(Fable, **PASS WITH CHANGES**, …)". Neither review record names its reviewer (CONTRACT-R3.review.md and DOCS-FRONT-DOOR.review-1.md have no model/agent line; the commit messages credit Opus). The lane convention at DOGFOOD-LOG.md:11-12 makes Fable the expected reviewer, but the header asserts more than the record shows. Fix: either drop "Fable, " from the header, or add a one-line "Reviewer: fresh Fable agent (`agent:claude-fable-5-1/…`)" to the top of CONTRACT-R3.review.md. Not blocking.

**N2 (info) DURABLE-STORE.md:6-7** — "every transition through the workflow kernel" is the reviewer's own replacement and is defensible (every event is applied by `WorkflowKernel.apply` in `Replay.state/1`, replay.ex:33), but the six Q1 ingress types (`ticket_admitted`, `artifact_frozen`, `artifact_blocked`, `stream_sealed`, `developer_closed`, `reviewer_closed`, `checks_started`; backend.ex:34-35) are planned with `Plan.unconditional` and never pass `decide/3` (backend.ex:165-180). A reader who takes "through the kernel" to mean "guarded by the kernel" will be misled; thin-lane Q1 already records this. Optional: "and every transition is applied by the workflow kernel". No action required.

**N3 (info, pre-existing)** test/foundry/workflow/r4_coverage_test.exs:1087, 1651 cite "WORKFLOW-CONTRACT.md:390"; that line was already not the lifecycle list at a076625, so the R3 insertion (+14 lines) did not cause it. Comment only; nothing parses it.

## Verified

- Read: AGENTS.md; both review records in full; the full `git diff a076625 26abc84`; WORKFLOW-CONTRACT.md :1-31, :112-150, :410-425, :450-460, :520-575; docs/README.md :20-30, :60-70, :85-122; LANE-RUNBOOK.md :140-150, :220-230; DOGFOOD-LOG.md :8-14, :190-200; design/bounded-effect-query-design.md :1-8.
- Code: manual_lane/log.ex :1-80; manual_lane/backend.ex :1-60, :100-185, :265-285, :325-400; manual_lane/cli.ex :25-110, :160-200, :380-400, :540-560; durable_store/gateway.ex :445-490, :556-582, :1405-1435, :1760-1790 and the `revision_conflict`/`idempotency_conflict` sites; protected_primitives.ex :5-12; launch_eligibility.ex :52-53; quota/fallback.ex :107-133; workflow/kernel/shared.ex :37; kernel/software/review.ex :288, :375; kernel/plan.ex :271-280; manual_lane/replay.ex :13-83 (signatures); test/support/r4_rows.ex :1-40; bin/check_docs.exs :1-52.
- Ran: `elixir bin/check_docs.exs` → `0 broken link(s)`, exit 0. `MIX_DEPS_PATH=… TMPDIR=/private/tmp MIX_ENV=test mix test` on the two R4 row-driven tests → 54 passed, exit 0. Full gate not run (running elsewhere).
- Conventions: review records carry no breadcrumb (matches every existing file in docs/batch-d/reviews/, e.g. ML-CONTRACT-DIVERGENCES.review.md:1-3); no test or CI file digests the contract text (grep of ci/ and test/ finds only `R4Rows` and two comments).
- Not verified: who ran the R3 review (N1); FR-10's future reconciliation path (does not exist).
