# Independent review: ML-PG-PACKET-PROVENANCE-DESIGN

**Verdict: correction.** Design only; no installed custody, Git/check certification or implementation approval.

- Base: `927bfd990fd9427eae16b85738ae531d4452d32d`
- Exact candidate: `4b78bb40e4992572c899edc79e28cd85ec7ea855`
- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-PACKET-PROVENANCE-DESIGN-1`
- Packet: `/private/tmp/ML-PG-PACKET-PROVENANCE-DESIGN.review-1.json`
- Own checkout: `/private/tmp/ML-PG-PACKET-PROVENANCE-DESIGN-review-1`, clean and detached at that candidate before and after checks.
- Entire range: one commit, only `docs/design/PORTABLE-PACKET-PROVENANCE.md` and `docs/README.md`, 36 insertions. Both paths are admitted scope.

## Ranked findings

### 1. P1 — The required rollout still contains a dependency cycle

**Location:** `docs/design/PORTABLE-PACKET-PROVENANCE.md:19`, against `docs/REPAIR-PLAN.md:156-158` and `docs/design/PORTABLE-CUSTODY.md:44`.

The design correctly requires a trusted CANDIDATE import before issuing a reviewer packet. But the actual candidate's plan requires CUSTODY to demonstrate a valid scoped human verdict, and CANDIDATE depends on CUSTODY. That positive verdict requires the reviewer assignment/packet now gated on CANDIDATE. Thus the acceptance graph is CUSTODY positive review → verified CANDIDATE import → completed CUSTODY. Saying the importer can call the seal API without issuing a packet removes a local API dependency, not the ticket acceptance dependency.

Line 19 acknowledges that the order must be revised *if* it requires a positive packet. The checked-in order already does. No explicit replacement ordering, split acceptance or trusted bootstrap import is specified. This does not meet the packet's express requirement to avoid the cycle. Scope does not permit this reviewer to change the plan or silently treat developer-only custody as full custody acceptance.

I also read the separate C7 integration plan as data at `/private/tmp/foundry-C7-autonomous-review-design/docs/REPAIR-PLAN.md:170-172`. It is not part of this candidate or its authority: it replaces the human positive with a positive REVIEW-BROKER scoped attestation, then makes CANDIDATE depend on REVIEW-BROKER. That alternative likewise needs an explicit resolution; its presence must not be misreported as a change already in this candidate's plan.

**Required correction:** specify a concrete acyclic, operator-reviewed implementation/acceptance order, retaining every positive acceptance obligation. For example, a separately admitted custody foundation could precede import, with full reviewer/broker acceptance after import; this is a proposal requiring explicit rescoping, not permission granted by this review. Name each deferred obligation and its owner. A kernel-only freeze, synthetic success fixture, or pretending a refusal satisfies the useful-positive requirement is not a resolution.

### 2. P1 — No authoritative consuming-entry selection exists at producer sealing

**Location:** `docs/design/PORTABLE-PACKET-PROVENANCE.md:9,15-19,29`.

The finite table determines an entry from the *issued effect's role*. For the submitting developer effect, that entry is `no_candidate` with `producer_roles=[]`. Yet sealing enumerates the *consuming entry's* producer roles and requires the submitting execution to be included. There is no protected attempt/assignment field or admission rule determining which future consuming entry is authoritative at this earlier transaction. The seal tuple pins the contract but not a selected consuming-role key. A controller-selected producer selector is expressly forbidden.

A concrete permitted table exposes the ambiguity: producer labels A and B; consumer X requires `[A]`; consumer Y requires `[A,B]`; an A execution submits in an attempt containing settled A and B producers. Both consumers and their edges can pass the stated admission rules. Which set must Core seal? The contract admits both, supplies no unique trusted selection, and permits only one immutable seal/submission and a one-to-one candidate binding. Selecting X excludes B; selecting Y changes X's required exact set. The two-role reference example hides the missing choice by informally assuming its one future reviewer. Exhaustive enumeration, a generation counter and restart reconstruction cannot establish completeness until the authoritative enumeration domain is fixed.

**Required correction:** specify the protected admission/assignment fact selecting the consumer entry (or a finite admission restriction making it uniquely derivable), pin that identity and its source through seal/import/issue/reopen, and reject incompatible consumer bindings. Define the no-consumer and multiple-consumer cases without hard-coded workflow labels or caller-selected lists. Add a static trace and future red control for two admitted consuming roles with different producer sets. A small ambiguity-refusal rule is preferable to a general workflow graph interpreter.

## What is sound, and what remains gated

- **Finite contract / complete response:** fixed modes, closed keys at every depth, exact return action, explicit no-candidate semantics, full producer/exclusion equality, historical policy and rejection of nonempty/unknown check sets are good constraints. Operator-owned role strings are data rather than new Core literals. No callback, selector language, formatter plugin, new role-specific privileged API or rule-3 exception is authorized. Completeness is conditional on resolving finding 2, not established merely by comparing a digest.
- **Initial spec:** line 11 explicitly requires an immutable operator-admitted spec snapshot and equality with domain ticket/attempt facts. That is a necessary new protected admission fact, not something existing `Backend.admit/3` proves: today it emits `ticket_admitted` after extending scope policy. Implementation must add authenticated admission and retained history before first packet issue, reject absent/mismatched snapshots, and never backfill them from a mutable projection.
- **Producer lineage:** the proposal includes all matching protected effects, earlier retries/non-starts, authenticated issuers, domain/effect bijection, predecessor linkage and claim/epoch attribution. Unknown or outstanding competitors block sealing; omitted and sibling producers refuse. Its generation/index and seal-cut history address phantom insertion and historical enumeration. It appropriately separates inbox attribution from issuer membership. Implementation must enforce this on every relevant mutation, not only the happy submit path.
- **Attribution is not certification:** submission bytes are unverified at sealing. Import binds actual Git facts and its trusted receipt to those exact bytes and seal, one-to-one; a free `artifact_frozen` ID cannot substitute. This is the right safety boundary; resolve ordering rather than weakening it.
- **Atomicity and historical recovery:** mandatory original bytes with issue/domain/result in one transaction, current read authorization before exposure, original request equality, refusal of fresh-ID duplication, historical reconstruction independent of today's active attempt and policy, and missing/corrupt history fencing are coherent. Include protected generation/absence keys in ReadSet; SQL serialization alone is not the claimed provenance check. Reassigned-to-another-candidate must not block an old exact result if the same actor still has scoped outcome-read permission.
- **Terminal non-start is NOT an available positive route.** Line 30's D1 non-start → D2 example is only a conditional design trace. The reviewed reconciliation design and its approving review explicitly leave the trusted non-delivery/quiescence source and operator-to-domain handoff undecided. No operator assertion, digest, expiry, issuer exit, current manual-lane attestation or packet recovery proves non-start. Until an exact claim/request/epoch/operation-bound source and replay rule are reviewed, retain unknown/holds/exclusions and prohibit the successor. This candidate supplies no such proof and cannot discharge that gate.
- **Revision changes:** sealed facts must not silently migrate. The new-attempt fallback is defined; any optional compatible revalidation path still needs its own bounded admission, mapping and reopen rules before implementation. V1's empty-check-only support cannot satisfy a nonempty-policy positive by displaying `policy_empty`.

## Source feasibility checks

Read AGENTS, top-level README, docs index, agent brief, portable milestone/dependency rows, boundary rule 3, workflow R1/R3/R4a, custody and reconciliation designs and their reviews, and the full conditional stopped packet-binding draft read-only as data. Inspected the required code paths:

- `WorkPacket.build/3` (`work_packet.ex:25-61`) requires the active attempt and an issued claim; candidate producer IDs come from domain executions. Its schema/encoder are reusable shape/encoding references, not protected provenance.
- `Backend.issue/6` and `packet/3` (`manual_lane/backend.ex:98-144,465-490`) issue first, then read live policy/ticket and add issuers separately. `excluding_developers/3` can silently omit a failed effect lookup. The proposed root-side exhaustive seal cannot reuse that as completeness proof.
- `Protected.Operations.create_effect` (`operations.ex:621-727`) records authenticated actor, role, attempt, execution and predecessor; `issue_claim` (`:831-880`) changes claims/reservations. Neither currently stores the proposed candidate seal or packet.
- `AtomicBundle.commit_atomic_bundle/6` (`atomic_bundle.ex:126-183`) supplies the existing transaction mechanism; its persisted result (`:583-684`) has no WorkPacket snapshot.
- `Protected.ReadSet.complete_read_set/3` (`read_set.ex:130-157`) requires exact dependency keys/revisions; claim reads (`:372-410`) do not establish the proposed identity/spec/seal/generation history. `Protected.RestartCheck` (`restart_check.ex:253-418`) checks exact bundle result fields and reconstructs plan/discriminator provenance. A new packet carrier must extend both rather than append unchecked bytes.

## Separate Ponytail Review — complexity only

The finite admitted table and existing transaction/result carrier are the smallest plausible approach. No new dependency, parallel journal, generic DSL or second lifecycle reducer is justified. Keep the two fixed semantics; resolve ambiguous consumer selection with the smallest protected fact/admission restriction. Producer membership generation, immutable history and complete-byte validation are required security mechanisms, not expendable complexity. The missing rollout decision is not a reason to build a bootstrap bypass. Complexity review does not override the two corrections.

## Checks, limitations and recording

- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS **469/800 words**.
- `git diff --check 927bfd990fd9427eae16b85738ae531d4452d32d..4b78bb40e4992572c899edc79e28cd85ec7ea855`: passed, exit 0.
- Exact HEAD, detached state, scope and clean worktree checked before and after inspection. No candidate/source/test edits; no staged files.
- Dependency-cycle and two-consumer cases above are manual counterexample analyses, not executable implementation tests. Per task, no focused suite, source mutation, full gate, FR-08A rebind, host provisioning, distinct-UID experiment, CI, service install, integration or push was run. No paused worktree was modified.
- Pre-review lane status: ready/reviewing, exact candidate, expected principal owns the issued reviewer execution.
- This file is the runtime-authoritative output path and is also the immutable lane-input notes file, overriding the other requested notes filename. It is written before recording and will not be revised after hashing. I will personally submit `correction` from the main checkout using this path and verify returned receipt, status, committed review event and archived note bytes. The final response reports that verification; this notes file alone is not the lane verdict.
