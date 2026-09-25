PASS WITH CHANGES

Reviewer: a fresh Fable 5.1 agent (`claude-fable-5-1`), read-only, not the author and not a fork; run outside the lane on 2026-09-25.

# Review: WORKFLOW-CONTRACT.md revision 4, R3 "Observability is not authority"

Checkout `/private/tmp/foundry-front-door-review` at `a076625`, read-only. Text under
review: `docs/WORKFLOW-CONTRACT.md:114-132` (added by `a531590`, 2026-09-20). Revision 3
text is context only.

Verdict: the rule is consistent with R1–R5, changes no decision, and the code honours it
(no path reads an observation, log, `operator.log.jsonl` line or observation page back to
decide anything). The defects are in precision: the paragraph does not define
"observation" while the contract and Core already use that word for things the system
*must* decide on; it attributes to "the R4 rows" two statements that live in R1 and one
that R4's text does not quite say; and it does not say which owner enforces which half,
although it sits in the protected-boundary section. None of these needs a decision; all
are wording.

## Findings

### F1 (medium, precision) — "observation" is undefined and collides with five uses where an observation is a decision input

`WORKFLOW-CONTRACT.md:114-116`: "An observation, telemetry record or diagnostic log is
evidence *about* the system, never a fact the system may decide on. No observation may
establish ... any protected fact."

Read literally, that contradicts the contract's own vocabulary:

- `:330` "Input time, IDs, **observations** and deadlines are explicit immutable inputs
  to pure `decide(state, command, inputs)`".
- `:423-424` (R1) "Receipts carry **observation ID** and claim ID; late old-epoch receipts
  can settle that claim" — a receipt settles a protected fact.
- `:432` (R4) "stale/duplicate **observations** are retained/deduplicated and do not
  mutate a newer owner" — i.e. fresh ones do mutate.
- `:442` (R4) "exit status/timeout/cancel are separate **observations**" — and R4.08.f3
  "verified exit/timeout" terminalises an attempt.
- `:521` R4.05 / `event.ex:116` `artifact_frozen` carries `observation_id`.

Core uses the same word for evidence it settles on: inbox `item_kind in ~w(result exit
observation)` (`lib/foundry/durable_store/protected_primitives.ex:772`), receipts as
`observation_receipts` / `observation_conflict?` (`:1548-1555`, `:1631-1633`) and the
refusal `:duplicate_receipt_observation` (`:1987`). The kernel's `execution_observed`
legitimately moves an execution `pending → starting → running` (`lib/foundry/workflow/
kernel/executions.ex:63-77`). A future reviewer holding the paragraph against any of these
cannot tell whether it is violated.

The paragraph means the *diagnostic* sense (telemetry, logs, observation pages, traces,
the free-text `observation` field), as `OBSERVABILITY.md:5-13` and `CONCEPTS.md:16-18`
put it. Say so.

Fix — insert after the first sentence at `:115`:

> Here an observation is a record made to explain or display the system: a telemetry
> record, a diagnostic log line, an `operator.log.jsonl` entry, an observation page, an
> exported trace, or the free-text `observation` an `execution_observed` event carries.
> It is distinct from the attributable evidence the contract does decide on — an
> authenticated command, a claim-bound receipt (R1), a sealed inbox stream (R4a) and a
> root-verified check or review receipt — which R1 and R4 also call observations when
> they name the delivery, not the authority.

### F2 (medium, misattribution) — "The R4 rows already say this one case at a time" cites two R1 sentences and one reading R4's text does not state

`:117-120`. Each cited case, located:

1. "a closed execution requires verified process/session termination or proved
   non-start" — **R4**, `:441`: "Execution lifecycle | ... closed requires verified
   process/session termination or proved non-start". Exact. ✓
2. "a check failure uses its controller's own `reason_code` rather than an agent's
   assertion" — **R4 prose**, not a row, `:557-559`: "A check failure uses its
   controller exit/receipt reason_code (assertion_failed, infrastructure_failed or
   timed_out), not an agent's assertion of infrastructure error." Close, but R4 is
   narrower ("of infrastructure error") and "controller" there means the check's
   controlling process, which collides with "Controller" = the kernel in the enforcement
   matrix (`:187-205`). ~
3. "a review verdict is read only from a sealed stream" — **not stated by R4**. R4.16
   (`:533`) and R4.17 (`:534`) list "Close/seal reviewer" as an *outcome* of a verdict,
   which reads the other way round. What R4/R4a do say: `:505-512` "On exit, the broker
   seals that execution's input stream ... It processes all inbox artifacts through that
   sequence before deciding no valid result exists ... Messages arriving after sealing
   are late evidence"; R4.19.f2 (`:536`) "sealed stream no valid verdict"; `:551-552`
   "Until that result validates, sealed inbox processing precedes exit failure." The
   strict form — no verdict is *recorded* before the seal — is the kernel's reading
   (`review.ex:288`, `:373-385`, comment "R4: a reviewer verdict is accepted only against
   a sealed reviewer stream"), stricter than the row text, and asymmetric with the
   developer, whose `artifact_frozen` needs no seal (`developer.ex:179-196`). ✗ as an
   "already says".
4. "pane closure alone cannot assert completion" — **R1**, `:394-395` "Finalization
   accounts for sessions, prompts, check/build tools, Git operations, release
   stop/switch/start and cleanup, not just panes"; `:405-406` "Old ref equality or
   missing pane alone is insufficient"; `:399-400` "observing expiry alone proves neither
   termination nor non-start". R4 has only "normal exit alone is not success" (R4.08.o3)
   and "Exit notifications cannot overwrite this" (R4.22.o4). ✗ as "R4 rows".

Fix — replace `:117-121` ("The R4 rows already say ... re-derived per row.") with:

> R1 and R4 already say this one case at a time — a `closed` execution "requires
> verified process/session termination or proved non-start" (R4 lifecycle row); a check
> failure "uses its controller exit/receipt reason_code ..., not an agent's assertion"
> (R4); no valid result or verdict is decided until the sealed stream has been processed
> through its last accepted sequence, and later messages are late evidence (R4a, R4.08,
> R4.19); and "missing pane alone is insufficient" and "observing expiry alone proves
> neither termination nor non-start" (R1) — and stating it once here makes it reviewable
> as a boundary instead of re-derived per row.

If the operator wants the kernel's strict form (verdict recorded only after the seal) to
be contract text rather than a kernel reading, that is a one-line R4 addition and should
be recorded as such, not smuggled in as "already says".

### F3 (low, testability) — placed in the protected boundary, enforced by the controller

The paragraph sits in R3 and says "any protected fact", but the three enforcements it
cites are kernel-only. Core validates only the *type* of `execution_observed`
(`lib/foundry/durable_store/record_codec.ex:86-99`: `map["type"] in @event_types`,
`plain_map?(payload)`), not its `lifecycle` value; `require_open_lifecycle`
(`executions.ex:351-355`) and `require_reviewer_stream_sealed` (`review.ex:375-385`) are
Controller rows in the matrix's own terms — "an adversarial controller can violate them,
and Core does not claim them" (`:187-189`). The protected half *is* Core's: a receipt
settles only its own claim (`settle_with_receipts`, `protected_primitives.ex:1540-1560`)
and "Root-derived fields ... cannot be supplied by kernel events" (`:98-100`). A reviewer
testing a future change needs to know which half they are testing.

Fix — append to the first paragraph, after "...without ever changing what is decided."
(`:126`):

> Enforcement is split as the matrix is: Core refuses an observation standing in for a
> protected fact (receipts settle only their own claim; kernel events cannot supply
> root-derived fields); the lifecycle half — an observation cannot close an execution, a
> verdict is recorded only against a sealed stream and never terminalises by itself — is
> the reference kernel's and holds only for that controller.

Optionally add the three as Controller rows to the matrix (`executions.ex`
`require_open_lifecycle/1` → `kernel_test.exs:345`, `:1336`; `review.ex`
`require_reviewer_stream_sealed/1` → `kernel_test.exs:1227`; `review.ex`
`do_transition("review_recorded", …)` records only, `dispositions.ex`
`do_transition("attempt_settled", …)` sole terminaliser → `kernel_test.exs:314`, `:863`).
The matrix rule (`:175`) does not require it — no new operation or slot — so this is a
suggestion, not a blocker.

### F4 (low, currency) — the header's "no candidate may cite it" is already contradicted by three docs

`BOUNDARY-RULES.md:28` (rule 9, added `fa812c9` 2026-09-23), `OBSERVABILITY.md:5` and
`CONCEPTS.md:16-18` all cite this paragraph as the rule's home, and `manual_lane/log.ex:3`
cites rule 9. The text is load-bearing while marked unreviewed. Not a defect of the
paragraph; on acceptance, update the header (`:5-9`) to record the review and drop the
caveat, so the citations stop pointing at unverified text.

### F5 (info) — the "three separate times in one subcommit" claim, checked against `6084ad3`

Subcommit 1 (`6084ad3`, "make the FR-08B kernel a guarded reducer") contains all three,
in `lib/pramana_foundry/workflow/kernel.ex` at that commit:

- `execution_observed` may not close: `require_open_lifecycle/1` (`:975-985`), test "an
  ordinary observation cannot close an execution" (`kernel_test.exs:413` at that commit).
- a review verdict needs a sealed stream: `require_reviewer_stream_sealed/1` (`:922-932`),
  test "a review verdict is refused before the reviewer stream is sealed" (`:304`).
- a verdict string is not a disposition: `review_recorded` records the verdict and does
  not advance the ticket (`:601-620`, "it does not advance the ticket, because R4 makes
  ready_to_integrate follow *verified reviewer close*, not the verdict"); only
  `attempt_settled` sets a disposition (`:690-700`). This one was enforced by structure,
  not by a refusal atom, and had no dedicated test at that commit (the write-once test,
  now `kernel_test.exs:314`, came later). Accurate, but a reader looking for a third
  refusal will not find one.

Suggested tweak at `:130`: "a verdict string is not a disposition (`review_recorded`
records it; only `attempt_settled` terminalises)".

### F6 (info, Q3 limit) — the manual lane's closure and seal are operator-command ingress, not verified termination

`lib/foundry/manual_lane/backend.ex:34-35` admits `stream_sealed`, `developer_closed`,
`reviewer_closed` through `ingress/5` (`:156-181`, `Plan.unconditional`), and `review/6`
emits `stream_sealed` with `last_accepted_sequence => 0` (`:226-230`) then
`reviewer_closed` (`:237-240`). These are authenticated commands by a principal, so the
paragraph is not breached — but "verified process/session termination" in the lane is
the operator's word, as thin-lane Q1 recorded (`THIN-LANE-DESIGN-2026-09-23.md:382-391`).
The paragraph forbids observations deciding; it does not make the lane's closures
verified. Worth one sentence in the header or a known-divergence entry only if the
operator wants the lane held to R4's `closed` row before FR-10.

## Answers to the four review questions

1. **Consistency.** Cited rows located and quoted above (F2). No conflict with R1 (it
   restates R1's pane/expiry sentences), R2 (`:221` "quota observations retain
   freshness/uncertainty" is the same stance), R4a (proved non-start is "attributable
   proof", not observation), R5 (`:591-592` "token/currency usage is diagnostic unless a
   provider can enforce"), the enforcement matrix (gap, not conflict — F3) or the known
   divergences. The terminology collision (F1) is the only place a literal reading
   contradicts contract text (`:330`, `:423-424`, `:432`, `:442`).
2. **Decisions and obligations.** Changes no R1–R5 decision. Adds no obligation not
   already implied once "observation" is read in the diagnostic sense: R3 `:98-101`
   ("Kernel projection labels never serve as acceptance evidence"), R1 `:399-406`, R4
   `:441`, `:557-559` and `:766-768` ("Diagnostic retention cannot erase authoritative
   work") already cover it. "This holds whichever surface..." and "the observability work
   may change what is measured..." are scope statements for FR-18B, not R1–R5 rules.
3. **Code.** No read-back path found:
   - `manual_lane/log.ex`: `trail/2` is read-only SQLite (`:31-39`), called only from
     `cli.ex:230` and rendered at `cli.ex:591`; `operator/2` is append-only (`:256-269`),
     called only from `cli.ex:550`; `notes/2` (`:190-194`) is read only to verify the
     archive digest (`:180`) and for display (`:137-161`). Nothing opens
     `operator.log.jsonl` for reading (the only `File.read`s in `manual_lane/` are
     `server.ex:218` policy seed, `cli.ex:505` the reviewer's notes input, `log.ex:191`).
   - `Foundry.Observations` (`lib/foundry/observations.ex`, `observations/*.ex`): a
     query surface over `Gateway.protected_snapshot/query`; no caller in `lib/`
     (callers: `test/foundry/observations_test.exs`, `test/foundry/durable_store/
     atomic_bundle_test.exs` only).
   - Core: `effect_observation_page` is a query (`protected_primitives.ex:591`,
     `:4318-4320`) and is not consulted by any `apply_operation` clause; settlement reads
     receipts bound to a claim (`:1540-1560`).
   - Kernel: `execution_observed` reads only `payload["lifecycle"]` (`executions.ex:73`)
     and refuses `closed` (`:351-355`) and any already-closed execution (`:337-344`);
     `review_recorded` requires a sealed reviewer stream (`review.ex:288`) and records
     only (`:289-293`); the phase advance is in `reviewer_closed` after `require_sealed`
     (`:311`, `:332-338`); disposition only via `attempt_settled` (`dispositions.ex`).
   - FR-08B claim: verified at `6084ad3` (F5).
4. **Testability.** Testable once F1 defines the term and F3 names the owner; F2's
   citations otherwise send a reviewer to rows that do not contain the words. Overstated:
   "The R4 rows already say ... a review verdict is read only from a sealed stream".
   Ambiguous: "observation", "controller".

## Verified

- Read: `AGENTS.md`; `WORKFLOW-CONTRACT.md` `:1-31`, `:79-205` (R3, matrix), `:209-350`
  (R2, identities, encoding), `:350-427` (R1), `:427-583` (R4, R4a), `:583-778` (R5,
  divergences, integration, gates); `BOUNDARY-RULES.md:26-36`; `OBSERVABILITY.md:1-30`;
  `CONCEPTS.md:10-20`, `:145-160`; `REPAIR-PLAN.md:375-400`;
  `fr08b-event-vocabulary-enumeration.md:100-175`; `THIN-LANE-DESIGN-2026-09-23.md:380-412`.
- Read in full: `lib/foundry/workflow/kernel/executions.ex`,
  `lib/foundry/workflow/kernel/software/review.ex`, `lib/foundry/manual_lane/log.ex`,
  `lib/foundry/observations/{source,observation,page,query,gateway_source}.ex`;
  `lib/foundry/observations.ex:1-40`; `checks.ex:1-80` and its `check_recorded` sites;
  `backend.ex:150-250`, `:440-452`; `record_codec.ex:18-60`, `:86-99`;
  `protected_primitives.ex:760-790`, `:1540-1560`, `:1975-1990`.
- Git: `a531590` (the paragraph's commit and message), `6084ad3` (subcommit 1: diff grep
  and the six function bodies), `fa812c9` (rule 9 date).
- Tests run (`MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps TMPDIR=/private/tmp
  MIX_ENV=test`): `kernel_test.exs:314`, `:345`, `:1227`, `:1336` → 4 passed, 127
  excluded; `manual_lane/cli_test.exs` + `manual_lane/backend_test.exs` → 39 passed, mix
  exit 0. Full gate not run.
- Not verified: FR-10's verified-termination path (does not exist yet); whether the
  operator wants the kernel's strict sealed-before-verdict reading promoted to R4 text.
