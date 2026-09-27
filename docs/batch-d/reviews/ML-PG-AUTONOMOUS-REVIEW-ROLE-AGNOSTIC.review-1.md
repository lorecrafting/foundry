# ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC — independent review 1

**Verdict: approved — design only.** No blocking finding remains in this exact candidate.

- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC-1`.
- Base: `927bfd990fd9427eae16b85738ae531d4452d32d`.
- Candidate: `92d678a3df1459e5f15e551f6e6bbc819272542b`.
- Packet: `/private/tmp/ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC.review-1.json`.
- Own clean detached worktree: `/private/tmp/ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC-review-1`.
- Reviewed both commits, `92cbf13` and `92d678a`, the original design body, correction delta and complete base-to-candidate diff. Six documentation paths changed, 70 insertions/14 deletions, all within packet scope. No source, test, role-site allowlist or frozen workflow-contract change.

## Ranked findings / outstanding gates

There are no requested corrections. These are remaining implementation and enablement gates, not implemented guarantees:

1. **Protected generic semantics must be implemented, not translated back into privileged reviewer behavior** (`docs/design/PORTABLE-AUTONOMOUS-REVIEW.md:13-15,23`). The new design supplies a closed bounded envelope, finite conjunctive manifest vocabulary, immutable fact matching, protected assignment provenance and mandatory producer inequality. It explicitly prohibits executable policy expressions, controller-minted authority and waiving root checks. Implementations must preserve those requirements, including every protected producer/predecessor, not merely the current submitter or a workflow-selected producer list. The required role/token replacement control at line 33 must pass without changing protected code; an old token, unissued capability or workflow-only assignment must fail. This approval does not widen rule 3.
2. **The no-execution identity boundary remains unproved on actual hosts** (`:17-19,33`). An ordinary Pi/Codex/Claude process under the desktop UID is not the specified broker. Implementation must inspect the real tool registry, extensions, configuration ownership, inherited descriptors, peer/endpoint credentials and every executable model-directed route. Candidate tests/search execute only under a different restricted UID without attestation authority. macOS and Linux hostile-tool, useful-positive, restart and scratch red controls remain necessary; unavailable/failing hosts stay disabled.
3. **Atomic results, authorization cuts and promotion exclusions require implementation evidence** (`:25-29,39`). Current-access checks precede old-result reads; completed mutation preconditions must not be rerun. Attestation/capability/result persistence and consumption must not expose authority without its durable exact binding. The carried reconciliation design requires the issuance snapshot in the same Core transaction. Automatic promotion still requires atomic current-fact validation, one durable effect and project exclusion through reconciliation, not just Git CAS. Terminal non-start proof sources remain undecided and unauthorized.

## Correctness and architecture review

The former role-specific design is not being approved by association with event 367. I read the operator follow-up as evidence, not a verdict, and reviewed the changed criterion independently. The final design explicitly separates software-workflow labels, assignment proposals and correction/rejection display from protected capability issuance and acceptance. A generic decision record cannot itself set a phase, create a check receipt, supply acceptance or choose a promotion target.

The manifest is meaningfully bounded rather than a renamed policy interpreter: its predicates are fixed equality/current revision, immutable receipt provenance/result, full Git scope/ancestry, enrollment/non-revocation, protected producer inequality, claim uniqueness and pending/exclusion state. Entries select and conjunct supported checks; unsupported predicates/evidence kinds, extra fields and incomplete bindings refuse. Mandatory root checks cannot be waived. Root matches envelope references to its own records. Producer lineage must originate in authenticated claim-bound submission and immutable import; decision-maker lineage must originate in protected issuance under admitted standing policy. A board assignment alone causes a hold. This is sufficient semantic design for the subsequent scoped implementation admission, not proof of an existing generic endpoint.

Actual `Protected.Guards.principal_independence/6` (`lib/foundry/durable_store/protected/guards.ex:151-280`) already treats role names as policy data, unions current and pinned effect policies, computes reverse pairings, and checks issuers plus inbox actors across the attempt. Its callers include effect creation (`protected/operations.ex:669`) and first inbox append. It is a reusable provenance/inequality pattern, not authenticated host isolation today. The candidate adds no Core role-literal site and does not require a reviewer-specific privileged API. An implementation that trusts an unprotected controller's chosen lineage would violate this design and rules 3/7, even if its ordinary happy path passed.

The closed bytes-only attestation request does not reintroduce privileged caller-selected file paths. Separate permanent attestor, producer, worker, operator and service identities preserve the reviewed custody boundary while replacing permanent workflow-role enrollment with principal/project/capability enrollment. Broker code/configuration remain operator-maintained. Peer authentication alone is insufficient if candidate code can run under the attestor UID; line 17 expressly disables that case.

### Counterexample traces (static, not executable host tests)

| Attempt/cut | Required disposition in the reviewed design |
|---|---|
| Controller invents a reviewer label, assignment, model/session identity or producer list | No protected authorization/provenance: hold; labels cannot issue capabilities or establish independence. |
| New admitted policy changes role/display names and token spelling | Supported capability/fact checks remain unchanged; only newly admitted permitted tokens qualify. No policy program or new Core literal is needed. |
| Attestor equals any authenticated producer, including predecessor lineage | Mandatory inequality fails; a new workflow label cannot cleanse that identity. |
| Correct token but wrong candidate/tree, spec/policy/base, assignment, receipt definition/result or incomplete required set | Exact immutable/current bindings fail. A workflow-complete label and self-reported check cannot substitute. |
| Known nonqualifying decision token | May record an attributable decision under its capability, but cannot satisfy acceptance. Workflow correction/rejection presentation grants no protected effect. |
| Attestation commits, consumes its claim, reply is lost; revision advances and service restarts | First verify current scoped outcome-read access, then return the original actor/request/content-bound result. No new attestation and no stale mutation-precondition check. |
| Same request with altered expected revision/content, sibling actor, fresh ID against consumed claim | Refuse; do not rebuild from current facts or issue a successor. |
| Revoke UID on an open socket or before restarted result lookup | Current revocation refuses even cached reads; no new decision/acceptance may use it. Possibly delivered work retains holds. |
| Missing/corrupt result or uncertain delivery | Unknown/refusal, no inferred success/non-start or replacement. Snapshot recovery does not prove non-delivery. |
| Policy/spec/base changes race promotion issue | Atomic validation plus durable project exclusion orders them; a separate pre-CAS observation is insufficient. |
| CAS succeeds then reply/settlement is lost | Exact verified new commit/tree settles the one effect; another promotion cannot interleave. Old value permits retry only after issuer/channel quiescence; third/corrupt/uncertain state holds. |
| Candidate changes root, broker, policy, gates or authorization configuration | Ordinary automatic route excludes it; ambiguous classification holds. Source acceptance is not deployment or operator-root installation. |

The earlier portable contract's full admitted-base scope, accepted-base equality and promotion authorization point remain in force. R3 still keeps the root outside candidate execution and permits no second workflow reducer. R4a still requires proved non-start, predecessor identity and bounded retry, not timeout/absence as proof. The reconciliation design is carried forward without selecting its unresolved terminal evidence sources.

## Migration and residual risks

The plan, Q23/Q24, design status pointers and amendment migration agree: historical `cfb2de8` approval is unintegrated and insufficient for this criterion; old ML-PG-CUSTODY packet/claim/check/verdict authority is not retroactively amended. New operator admission, policy, identities and exact-candidate checks/review precede custody implementation, then broker, candidate/check and acceptance/promotion work. Historical designs and WORKFLOW-CONTRACT are not silently rewritten. Current manual-lane records remain supervised, not protected acceptance.

Same-OpenAI producer/reviewer models can share errors despite distinct principals and sessions. Source/check-output prompt injection can still persuade the attestor to issue a bad judgment; no-exec custody prevents credential/tool crossover, not semantic deception. Line 35 explicitly records provider/model lineage and evaluation of false approvals, legitimate refusals and recovery cost. Operator/root compromise and kernel exploits remain outside the stated boundary. This review supplies no real-host isolation, provider/network containment, installed broker or automatic-promotion evidence.

## Separate Ponytail Review

Lean enough. Reuses the reviewed custody socket/identity boundary, existing protected transaction/provenance concepts and fixed Git CAS rather than inventing another controller, policy language or authority store. The closed generic manifest is necessary for the requested architecture, not a speculative workflow framework. No dependency or implementation scaffold was added. No deletion requested; removing mandatory provenance or result bindings would remove requirements.

## Checks and limitations

- Verified exact HEAD and clean detached checkout initially and after focused checks.
- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS **469/800 words**.
- `git diff --check 927bfd990fd9427eae16b85738ae531d4452d32d..92d678a3df1459e5f15e551f6e6bbc819272542b`: passed.
- Python/git assertions: **2 commits; 6/6 changed paths in packet scope; documentation only; Core, architecture role-site allowlist and frozen contract unchanged**.
- Read AGENTS, docs index/top-level README, agent brief, boundary rules, strategy working summary, portable plan/Q23 supersession, R3/R4a, the three prior designs and their approving reviews, lane runbook, relevant Core callers and the full candidate range.
- No runtime tests, full gate, FR-08A rebind, source mutation/red probe, sudo, account provisioning, service installation, CI or live host acceptance ran. Static counterexample traces are not execution evidence. Historical CI counts were read as reported history, not independently rerun.
- Candidate and checkout were never edited; no staged files.

## Lane recording

These immutable notes are the lane-input evidence, separate from the runtime-bound final response. I will personally submit one `approved` verdict with the exact packet principal and candidate, then verify its returned receipt, status/log and archived notes digest. The lane receipt, not this file alone, establishes the committed verdict. Design approval enables only the next scoped admission/review steps, not the protected route.
