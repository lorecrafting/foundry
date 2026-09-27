# ML-PG-CUSTODY-RECONCILIATION-DESIGN — independent review 2

- Verdict: **approved — design only**, for exact `a6907df758585db4bcb6034e7e396840f2789b80`.
- Admitted base: `7a41ada9e6a589af17845b0c41b146c92e44424c`; prior candidate: `df14eefd3f2131cccf8778ae1a73c8559892da98`.
- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-CUSTODY-RECONCILIATION-DESIGN-2`.
- Packet: `/private/tmp/ML-PG-CUSTODY-RECONCILIATION-DESIGN.review-2.json`.
- Fresh independent reviewer, no delegation. Environment: `openai-codex`, `gpt-6-astra`, reasoning `high`.

Verified clean detached HEAD at the exact candidate before and after checks. Reviewed the full two-commit range and the correction separately: only the packet's three documentation paths changed, 37 insertions/1 deletion. Read the complete prior review, AGENTS, agent brief, documentation index/top-level README, governing repair-plan/milestone sections, approved custody design and contract plus their approving reviews, relevant R1/R3/R4a contract sections and lane runbook. Inspected actual Core/Backend/WorkPacket sources and read-only unmerged Custody at the separately verified clean detached `/private/tmp/ML-PG-CUSTODY-review-5`, exact `bb8617e02cfcd13e2e6bfe5f935d952132e0207c`.

## Ranked findings and disposition

**No blocking finding remains in this proposed-only design.** The prior P1 is resolved: `docs/design/PORTABLE-CUSTODY-RECONCILIATION.md:23-25,32-33` now specifies a concrete original-result protocol, commitment order, exact bindings, refusal behavior and restart/red controls rather than deferring that protocol to another ticket.

The following are ranked **outstanding implementation-authorization gates**, not claims that this candidate implements them:

1. **Terminal operator non-start remains unreviewed/unavailable** (`:18,21,29,35`). The positive/restart bullet at line 29 is a conditional future acceptance scenario, NOT an approved positive terminal route. No installed source proving exact non-delivery and issuer/channel quiescence has been selected. Nor is there a concrete typed operator-decision-to-workflow handoff. Line 35 explicitly leaves support for non-start versus unknown-only undecided; lines 5 and 21 require decisions and a reviewed cross-boundary rule. This approval does not discharge those conditions. Before enabling a terminal command, choose and review the proof source, its exact claim/request/epoch/operation binding and conflicting/late-evidence behavior; specify the authoritative output, domain binding and reopen validation. Otherwise retain unknown/holds/exclusions. A digest, operator statement, issuer exit, expiry, missing pane or successful packet recovery is not that proof.
2. **The packet result carrier and access barrier must be implemented and reviewed together** (`:23,32-33`). AtomicBundle has no packet snapshot today. Extending only the response map or adding a post-launch policy write is insufficient. The transaction, required read dependencies, closed result schema, authoritative reconstruction/restart validation and every protected packet/consumption route must agree. Historical missing results stay pending, never backfilled from current facts. This is a specified future protocol, not demonstrated durability of the proposed bytes.
3. **“Current assignment” means current access, not the completed mutation's old assignment** (`:25`, read with approved custody design `PORTABLE-CUSTODY.md:33`). A still-authorized actor's exact old request must survive a later attempt/candidate assignment and changed authorization revision. Its original expected revision is compared with stored request content, not required to equal the live revision. A caller that loses current project/outcome-read permission, or is revoked, still refuses. Implementing this phrase as a check that the old candidate/attempt remains assigned would reopen the already-resolved retry-ordering defect. No such change is authorized here.

The repair-plan/index changes preserve the parent obligations and consistently describe unimplemented design. Approval is not blanket permission for protected Core work, an installed custody acceptance, an authoritative protected human verdict, candidate/check certification, or promotion/integration.

## Source feasibility and correctness review

### Atomic original packet

- `AtomicBundle.commit_atomic_bundle/6` (`lib/foundry/durable_store/atomic_bundle.ex:126-183`) wraps protected staging, domain commitment and durable bundle result in one database transaction. `commit_accepted_atomic_bundle/7` (`:409-478`) commits the bound domain state, persists records and validates authority before commit. `persist_atomic_records/8` and `atomic_result/7` (`:583-684`) persist the existing command result, not a WorkPacket. The candidate accurately identifies both the reusable mechanism and the necessary extension.
- Issuance is real, not a display step: `Plan.launch/3` and `launch_operations/2` (`kernel/plan.ex:64-156`) stage reserve/create/claim/issue and bind launch authority into the domain event. `Protected.Operations.apply_operation/2` for `issue_claim` (`operations.ex:831-880`) changes the claim/effect to issued and reservations to issued_unknown under epoch, policy/control and predecessor checks. Therefore the new snapshot must commit in that transaction or all those writes roll back. A check after Backend returns is too late.
- Current Backend issues before building the packet (`manual_lane/backend.ex:98-144,465-490`); its builder reads the current replayed ticket and policy and fills excluded developer principals separately. `WorkPacket.build/3` (`work_packet.ex:25-61,143-162`) requires the active matching attempt and an issued claim. Encoding is canonical JSON with a trailing newline (`:71-76`). The design correctly forbids using that mutable read pipeline for historical recovery. Construction must use transaction-pinned spec/policy/candidate/check/independence facts, including the excluded issuers, and staged issued/domain state; recovery serves the committed response bytes, not a newly encoded current packet.
- The current carrier is closed: AtomicBundle validates its envelope keys (`:798-804`); `Protected.RestartCheck.validate_bundles/2` requires the exact result keys and revalidates operation/domain/plan binding (`restart_check.ex:253-418`). Merely attaching packet bytes would not constitute a compatible extension. Read-set issuance currently follows claim/effect/policy/control/reservation/lease dependencies (`protected/read_set.ex:372-410`), not custody enrollment. The candidate's explicit current-enrollment/assignment CAS requirement must extend that protection; a service-side precheck alone does not suffice.
- The new text closes the previous issuance-to-result gap: a newly issued claim and its complete immutable original response become durable together; cache completion is derivative only; alternate packet/read/submit routes cannot expose or consume before that barrier. Failure to obtain or encode any required fact rolls back issuance. No future reconstruction from a matching effect ID is accepted.

### Identity, retries and duplicate prevention

The design distinguishes the immutable request/snapshot binding from current authorization. Read authorization occurs first; stored actor/UID/role/project/request/digest and pinned result identity then match. A packet retry carries the full canonical request, including the old expected revision; request-ID-only result reads validate the recorded intent/snapshot binding. Claim consumption, current policy/spec/candidate changes and a later active attempt cannot substitute new packet facts. The stored claim writer epoch stays original across new Gateway epochs.

Unmerged `Custody.dispatch/5`, `access/5`, result lookup and `ordinary_execute/8` (`custody.ex:183-476`) demonstrate the distinction that must survive: current non-revoked enrollment and scoped access are checked, but completed matching requests bypass `fresh?/4`. The same reviewer may receive a later candidate and still retrieve the old outcome; replacement by another principal removes current access, and the replacement cannot read the former owner's result. UID/principal/role reuse remains forbidden. The focused controls below confirm both cases; none justify skipping revocation checks.

A fresh request ID cannot reuse the old operation or redirect a pending intent to a successor. Core's existing semantic operation and predecessor guards (`protected/guards.ex:389-484`) are relevant backstops, not substitutes for custody's original request/result association. A genuinely admitted later launch has its own current preconditions and lineage; it is never the old request's recovery result. Sibling actor/project, changed body/expected revision and absent/corrupt/mismatched snapshot refuse. Refusal to read does not prove the operation never ran or release its holds.

### Conceptual cut matrix (not tests of an implemented snapshot)

| Cut | Required outcome |
|---|---|
| Intent committed, before issue; reopen twice | No issued claim/reservation/packet authority from the intent. Exact retry may issue once only under current authorization and mutation preconditions; revoke/reassignment or stale mutation dependencies must prevent issue. |
| Protected issue staged, domain or encoding/snapshot write fails | Entire issuance bundle rolls back; no packet exposure or claim consumption. Reopen cannot see issued-without-result for the new protocol. |
| Bundle commits, reply/cache completion lost; reopen twice | Authorize current outcome read; resolve original intent to original committed snapshot; return identical canonical bytes without launch. |
| Claim consumed, current facts changed, later attempt active; reopen twice | Same authorized original bytes and original epoch/spec/policy/check/candidate/independence; no old issued-claim/active-attempt requirement, no successor mutation. |
| Same actor assigned later candidate, expected authorization revision now stale | Exact completed retry still returns original outcome if current scoped read permission survives. Changed incoming expected revision conflicts with the stored request. |
| Current read permission removed, sibling actor/project, revoked UID on old connection or after reopen | Refuse before returning bytes; no impersonation or resurrection by request ID. |
| New ID against existing operation; missing, conflicting or corrupt snapshot | Refuse/keep unresolved; no duplicate issuance, mutable rebuild, refund or release inferred. Corruption may fence Gateway; it is never a successful result. |
| Historical issued claim without snapshot | Pending/unknown with the applicable exclusions; a second reopen or operator attestation cannot invent its bytes. |

Implementation acceptance must assert exact response equality and unchanged original/successor effect, claim, reservation and ordinal counts for the post-issue read cuts. The before-issue positive necessarily creates them once. The specified barrier-removal, post-launch-write, current-packet substitution, identity/digest bypass and corruption red controls target distinct failures.

### Separate operator protocol

Ordinary issuer provenance stays intact: `Operations.settlement_provenance/3` (`operations.ex:1350-1362`) binds authenticated actor, request, channel and quiescence epoch; `reconciled_settlement/5` and `first_settlement/5` settle original reservations and leases, with unknown retaining uncertainty. Backend independently binds issuer and receipt (`backend.ex:359-391,417-429`). Operator authentication cannot satisfy issuer identity by assertion.

For eventual non-start, `Plan.nonstart/3` (`plan.ex:163-191`) expects a receipt-derived settlement and infrastructure discriminator. `TransitionPlan.closes_named_execution?/4` (`transition_plan.ex:732-747`) binds it to the exact effect's ticket/attempt/execution; restart reconstructs the plan from authoritative staged results. An operator-authored decision is not currently such an output. A reviewed extension must preserve this binding and original ledger/lease settlement and bounded ordinal, with the correct developer versus reviewer row, atomically. Unknown-to-known evidence must be separately attributable, not overwrite an earlier decision. Delivery is not review seal, verdict, termination or closure. A recorded correction/rejection can move the active pointer; resuming an already-proved original closure must not become a new terminal decision about a successor.

The positive terminal operator scenario remains gated as finding/gate 1 states. This design does not choose a proof source, invent a human review, relax ordinary receipt provenance, authorize every R4a outcome or move the lifecycle reducer into Core.

## Separate Ponytail Review — complexity only

Lean already. No new dependency, second authority store, generic recovery framework or speculative abstraction to delete. Reusing Core's transaction/result mechanism is the smallest defensible design; removing its snapshot or authentication bindings would remove requirements. **Net: 0 lines proposed for deletion.** This assessment does not authorize the outstanding operator protocol.

## Checks and limitations

All artifacts below are outside the checkout, with prefix `/private/tmp/ML-PG-CUSTODY-RECONCILIATION-DESIGN-review-2-`.

- `elixir bin/check_docs.exs`: **0 broken links**, AGENTS **469/800 words**, exit 0 (`docs.log`).
- `git diff --check 7a41ada9e6a589af17845b0c41b146c92e44424c..a6907df758585db4bcb6034e7e396840f2789b80`: exit 0; exact scope confirmed.
- Candidate/main-source focused tests: `mix test test/foundry/durable_store/atomic_bundle_test.exs:313:356:389:452:1289:1735 --seed 18713`: **6 passed, 36 excluded** (`core-probes.log`). These cover three transaction rollback cuts, committed reply loss/reopen, actor/content/order conflicts, corrupt nested result fencing, wrong-execution settlement rejection, and plan-bound reopen/backup. They verify existing carrier behavior, not the proposed WorkPacket extension.
- Exact unmerged-source probes: inspected and ran `/private/tmp/ML-PG-CUSTODY-review-5-regression_test.exs:167:237:253:281 --seed 18713`: **4 passed, 5 excluded** (`custody-probes.log`). They cover old authorized results after same-reviewer reassignment, the still-broken consumed/lost packet cut remaining safely pending, revoked unknown settlement and refusal of operator impersonation through Custody/Backend/Core, and changed-assignee/sibling/revoked old-result denial. Synthetic UID inputs and legitimate scratch Core writes, not OS-authentication tests. Two unused-helper/alias warnings were nonfatal.
- Both test commands used `TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps` and distinct external `MIX_BUILD_PATH`s. Total: **10 focused tests passed**. Relational oracle reported zero accepted-transition witnesses; no relational invariant proof is claimed.
- Controlled fault/data-corruption checks are the existing focused tests above. No source guard mutation was performed: this candidate changes no executable guard. Multiple-reopen snapshot cuts were analyzed conceptually, not run against a nonexistent implementation.
- No candidate/source edits, full gate, FR-08A rebind, sudo, provisioning, service installation, CI, live socket-kill experiment, actual distinct-UID hostile-tool acceptance, protected trusted-human verdict, PR, integration or push. Both reviewed worktrees remain clean.

## Lane recording

I will personally record **approved** using the packet principal, exact candidate and this notes path, save `/private/tmp/ML-PG-CUSTODY-RECONCILIATION-DESIGN-review-2-receipt.json`, and verify the exact candidate/principal/verdict in lane status and log. Pre-review status was ready/reviewing with the expected issued reviewer execution (`status-before.json`). The receipt and committed events, not this notes file alone, establish the verdict. **Design approval never means installed custody accepted.**
