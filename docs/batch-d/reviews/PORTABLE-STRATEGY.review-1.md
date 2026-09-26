# Independent review: portable governance priority amendment

**Verdict: correction required before landing.** The operator's direction is sound, including completing C2 first, but the milestone's integration acceptance is weaker than its stated protected boundary and the binding contract. Three smaller documentation corrections are also needed.

Reviewed exact draft **`8b49bb5653f10023cb8d1fdfacf7e6194aa9b933`**, against **`da3bb3c54d19b0774f35ee0a4280b75519b1ec20`**, in detached `/private/tmp/foundry-portable-strategy-review`. This is an independent GPT-6 Astra strategy review outside a lane ticket; it is not a lane verdict or implementation approval.

## Prioritized findings

### 1. P1 — Recording manual integration does not establish the promised protected integration boundary

**Changed location:** `docs/REPAIR-PLAN.md:151` (ML-PG-ACCEPTANCE); related promise at `docs/batch-d/DOGFOOD-LOG.md:43`.

The acceptance ticket requires binding a review and recording the actual manually integrated ref/tree. Its negative controls concern false or mismatched records. None requires protecting the accepted ref from a direct write, enforcing old-ref CAS at promotion, revalidating a moved base, or reconciling a promotion that happened before its receipt was committed. Thus the ticket can pass by recording an honest post-hoc observation while an agent can still bypass the gate and change the product's accepted ref. Refusing the subsequent record does not prevent that integration.

The binding contract explicitly requires an unchanged accepted base, exact reviewed tree/spec/policy, fresh checks and review on a changed base, and an issued claim followed by fixed old-to-new `git update-ref`, with crash reconciliation (`docs/WORKFLOW-CONTRACT.md:737–749`). These obligations concern integration, not agent orchestration, so excluding a bundled controller does not remove them.

Existing code supplies no missing guarantee: `lib/foundry/manual_lane/cli.ex:248–270` implements `integrated` as a read-only `git cherry` inclusion query. It neither promotes a ref nor checks the resulting tree against the approved tree, and `docs/batch-d/LANE-RUNBOOK.md:157–159` explicitly says it records nothing. The draft correctly calls the lane a starting point, but must identify this additional work before claiming protected integration.

**Minimal correction:** make ML-PG-CONTRACT define the authoritative accepted ref, its exclusive writer, and the distinction between acceptance, promotion and an observation of an external ref. Make ML-PG-ACCEPTANCE require operator-triggered protected promotion of the exact reviewed candidate, old-ref CAS, moved-base refusal/fresh evidence, and durable effect recovery. Include direct-write and crash-after-ref-update controls. This need not add agent launch, scheduling, autonomous activation or a reference controller. Split promotion into a follow-on packet if the resulting acceptance implementation is too large. If the intended scope is only observing external integration, explicitly narrow the product claim and retain that as an observational limitation; it cannot satisfy the current promise to protect actual integration.

### 2. P2 — Validation permits calling a confirmed risk “prevented harm”

**Changed location:** `docs/strategy/VALIDATION.md:38–42`; compare `docs/REPAIR-PLAN.md:153`.

The plan prohibits calling an unobserved hypothetical harm prevented. The validation rule nevertheless permits “prevented harm” when the baseline accepts the same unsafe attempt and an adjudicator confirms only its risk. Those observations establish incremental prevention of unsafe acceptance. They do not establish that downstream harm occurred or would have occurred. A vulnerable change accepted by the baseline may never be exploited, for example.

**Minimal correction:** call this outcome **prevented unsafe acceptance** (or incremental blocking of an unsafe attempt). Reserve downstream harm claims for separately observed outcomes during the declared follow-up. Keep the matched input, real baseline, independent adjudication and denominator requirements; they are appropriate.

### 3. P2 — The new queue's status summary contradicts completed FR rows

**Changed location:** `docs/REPAIR-PLAN.md:132–134`; related current handoff at `docs/batch-d/DOGFOOD-LOG.md:23`.

“Existing FR-08B–FR-22 full-scope obligations ... stay open” sweeps in completed FR-15aA, FR-19A and FR-21 (`docs/REPAIR-PLAN.md:568,575,578`). In the other direction, the updated handoff still says “FR-23b done”, while the inventory at line 580 now correctly marks it partly integrated and the same handoff schedules its remaining decompositions. A cold reader cannot use both summaries as status truth.

**Minimal correction:** say **remaining unresolved FR-08B–FR-22 obligations stay open; completed statuses remain unchanged**. Change the handoff's parenthetical to **FR-23b namespace/legacy cleanup integrated; decompositions remain**.

### 4. P2 — The new O1 distinction overstates independence from the existing kernel

**Changed locations:** `docs/design/ORCHESTRATOR-BOUNDARY.md:948–950`, `docs/REPAIR-PLAN.md:152`.

It is correct to distinguish the early client seam from O1's deferred default-controller adapter. But saying the seam “does not wrap or activate the FR-08B reference workflow kernel” is too strong when its stated implementation is the existing manual lane: `lib/foundry/manual_lane/backend.ex:120` already calls `WorkflowKernel.decide/3` for packet issuance, and its review flow also uses that kernel. Meanwhile the plan labels the work “O1 client seam”, inviting the very dependency confusion the new paragraph is intended to resolve.

**Minimal correction:** label ML-PG-CLIENTS **manual-lane client seam**. Say it adds no default-controller adapter and does not activate the unfinished autonomous lifecycle; it may reuse the kernel semantics already exercised by the manual lane. Preserve O1's full FR-08B dependency for that deferred adapter.

## What holds

- The active queue puts reviewed precision tooling and both behavior-preserving Core decompositions first. Q16–Q18 and the amended FR-23 rebind rule support one rebind per split, followed by one local batch gate and PR CI. The operator loop explicitly requires both checks green before local main fast-forward (`docs/batch-d/DOGFOOD-LOG.md:78–81`). No gate or integration success is invented.
- The six proposed milestone packets form an acyclic chain. ML-PG-CONTRACT appropriately requires an independently reviewed design before code. Full FR dependency rows remain separate from these newly authorized slices.
- Custody, principal authentication, immutable candidate evidence, trusted checks and distinct reviewers are stated requirements, not claims about today's CLI. Today's asserted principal, mutable checkout and empty-check-set paths (`manual_lane/cli.ex:175–189,399–412`; `git_evidence.ex:1–7`) need the planned replacement. The contract design should make hostile check-worker isolation explicit under custody: project tests are arbitrary candidate code even when the configured check command is trusted. This follows the existing protected-store promise and does not require a provider harness.
- Checkpoint/deferred-work wording preserves later autonomous repair rather than claiming its completion. Pi and the bundled controller are optional later investments. No remote-service or provider conformance is inferred.
- The prospective LokaCore comparison uses the native workflow's real permissions, review and CI, matched task classes, independent assessment, operator hours including setup and maintenance, false blocks, uncertainty and an observation window. Its shadow-period and second-real-client limitations are appropriately explicit. Apart from finding 2's harm terminology, it can measure incremental benefit without treating refusal counts as value.
- The two added precision-tool review records name their exact candidates and distinguish their checks from a full gate. Their historical test outcomes were read, not independently rerun or adopted as evidence for this strategy review.

## Separate Ponytail Review

Applied `/Users/raymondluong/.codex/plugins/cache/ponytail/ponytail/4.10.0/skills/ponytail-review/SKILL.md` to the actual documentation delta, separately from correctness. **Lean already. Ship.** No safe deletion or speculative implementation abstraction identified; **net: -0 lines possible**. This complexity verdict does not override the corrections above. Keep the protocol design bounded before admitting custody/check/promotion implementation; the six rows are outcome packets, not permission for one cross-cutting implementation.

## Checks, limits and worktree

- Confirmed detached HEAD equals the exact requested draft; clean working tree before review.
- Reviewed all eight changed paths and the plan, relevant binding contract and authority sections, strategy, validation, orchestrator boundary, handoff/runbook and agent instructions. Inspected the actual manual-lane CLI/backend and Git evidence paths for the reuse and integration claims.
- `elixir bin/check_docs.exs`: **0 broken links**.
- `git diff --check da3bb3c54d19b0774f35ee0a4280b75519b1ec20..8b49bb5`: **passed**.
- Final `git status --porcelain=v1`: **empty**; candidate worktree unchanged.
- No full gate, focused implementation tests, CI job, provider session, daemon/lane command, credential experiment or LokaCore pilot ran. This is a design/document review; no runtime security or product-value claim is certified.

Only this report outside the repository was written. Seek renewed review of the integration-boundary correction before landing the reprioritization.
