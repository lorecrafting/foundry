# ML-PG-CUSTODY-PACKET-ARCH-DESIGN — independent review 1

**Verdict: approved — design only. No blocking findings.** This approves only the exact documentation candidate, not the suspended prototype, Core implementation, host provisioning, terminal non-start, reviewer broker, protected acceptance or activation.

- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-CUSTODY-PACKET-ARCH-DESIGN-1`.
- Packet: `/private/tmp/ML-PG-CUSTODY-PACKET-ARCH-DESIGN.review-1.json`.
- Complete range: `927bfd990fd9427eae16b85738ae531d4452d32d..7cda7fe683034a71eedbfdeb9ec550b44a17926b`, one commit, two admitted documents, +51/-0.
- Own detached checkout: `/private/tmp/ML-PG-CUSTODY-PACKET-ARCH-DESIGN-review-1`; exact HEAD and clean initially and after checks. No candidate edits or staged files.
- Main read at clean `ab7f6cd9b97643a76767aaa06b898a5a62f20a18`; prerequisite read at exact `a86ebce9e1f2a4c16c1d125ceaa02e77edea56e7`, with its independent review 2. C9 integration checkout is clean at `4520c585371e1e743c42a0382f0fcbc4f5d1d79b`. Its local gate pass is supplied task context, not a gate run by me; PR/main landing remains pending at this review boundary.

## Ranked findings

No P1/P2 correctness, authority or scope finding. No correction requested. The remaining work below is expressly deferred by the candidate and is not evidence of installed guarantees.

## Correctness and adversarial design review

### Complete response and independent authority

Reviewed every changed line and traced the existing `WorkPacket.build/3`, its closed packet/nested keys and canonical newline, `Backend.issue/6`, `packet/3`, issuer enumeration, AtomicBundle transaction/result persistence, ReadSet and relevant RestartCheck bundle/history reconstruction.

The proposed field table (`PORTABLE-CUSTODY-PACKET-BINDING.md:19-28`) covers all 21 original v1 top-level keys and all nested candidate, independence, checks and return keys. Identity fields are cross-bound to authenticated complete intent, staged protected issuance and matching domain execution. Base/ref/title/spec/scope/criteria require immutable operator admission, not a controller projection. Checks and independence use complete historical protected policy; return uses an endpoint-authorized historical contract entry. No output field needs an unchecked formatter assertion.

The two fixed modes and finite, operator-admitted opaque-role entries (`:11`) preserve rule 3 and R3. Developer null candidate/empty exclusions/submit and imported consumer candidate/full exclusions/review are admitted data, not new Core role literals. Unknown or unauthorized entries, callbacks, caller-selected binding lists, templates and digest-only assertions are explicitly excluded. A root-owned formatter alone is correctly rejected as insufficient independent proof.

Attack: change any response field and recompute its digest. Full reconstruction and canonical byte equality still reject it. Attack: change domain spec/freeze, or select a different return action. Operator admission or verified import/endpoint equality rejects it; the domain is a corroborating relation, not authority. Extra/duplicate/missing keys, reordered lists, altered types and noncanonical encoding refuse. The implementation must preserve this distinction rather than treating a matching digest as semantic proof.

### Producer seal and import

The selected future consumer is fixed in the protected spec before producer issue, separately from the producer's own packet entry (`:11,30-32`). For X=[A], Y=[A,B], choosing Y prevents a caller from selecting X to omit B; later X cannot consume the Y seal. Exhaustive protected effects/domain executions, authenticated original issuers, claim/epoch/predecessor history and absence/generation dependencies must match. Failed eligible producers remain in the set; multiple executions sharing one issuer retain all execution IDs while exclusions are unique.

A submission seal retains unverified bytes and membership, not Git/check validity. Import binds exactly that retained submission and seal one-to-one to the independently verified candidate and receipts. Consumer issue requires matching freeze and trusted checks. Sibling producers, omitted issuers, unmatched domain executions, a bare `artifact_frozen` ID or altered import bytes cannot manufacture authority. The prerequisite explicitly distinguishes the submitting issued producer from *other* outstanding producers; missing or possibly competing lineage blocks the seal. This proposal relies on that reviewed prerequisite rather than authorizing a weaker subset enumeration.

### Atomicity, retry and restart

The mandatory `packet_result_v1` is staged with one productive issue, bound domain launch and original intent/result (`:17`). All successful new issuance must have exactly one result in the same database transaction. Claim/effect/reservation/domain/snapshot roll back together on failure. Alternate packet/result/submit/settlement consumption routes cannot bypass the barrier. Existing AtomicBundle staging is reusable, but its current closed result schema does not yet carry this result; normalizer, transaction, read-set, consumers and restart validator must change together.

A lost reply does not cause launch again. Current peer enrollment, non-revocation, project and outcome-read permission are checked before lookup/exposure (`:36`); then exact UID/principal/project, full original request bytes including the old expected revision, intent and snapshot association are checked. Current mutation revision, current claim-issued state and active attempt are not prerequisites for recovering a committed result. Thus consumed claim/moved attempt/repeated reopen preserve exact bytes. A sibling/revoked caller, changed request, wrong project or fresh request ID against an already-issued target refuses. Request-ID-only result reads still verify the stored original intent/snapshot association.

Restart reconstruction (`:38`) requires historical authenticated admission/enrollment, operation/domain result, policy/contract/claim/epoch, producer history through the seal cut, import/check provenance and canonical bytes/ref. Merely loading today's WorkPacket or coherently changing snapshot and digest is insufficient. Missing/corrupt new-protocol history fences readiness or demonstrably all affected productive/consuming routes. Historical unsnapshotted claims are classified pending/unknown with unresolved holds/exclusions, never backfilled from mutable state. Current access remains separately checked at each read.

Terminal non-start remains unsupported without separately reviewed exact non-delivery/channel-quiescence evidence and typed atomic R4a handoff. D1 unknown retains holds and prohibits D2. Packet recovery, issuer exit, expiry or an operator assertion cannot advance that trace.

### Dependencies and useful positives

Main Q25 remains authoritative: FOUNDATION authenticated developer packet/seal -> CANDIDATE independent import/checks -> REVIEW-BROKER actual isolated agent positive -> CUSTODY-CLOSURE -> ACCEPTANCE. Import does not require an existing reviewer packet or full closure. Foundation does not certify Git, issue reviewer decisions or promote refs.

V1 deliberately refuses every nonempty/unknown required-check set (`:25,30`). A broker positive requiring nonempty checks needs a separately admitted complete schema, contract, policy and **fresh attempt**, before its producers issue. Passing checks are never displayed as `policy_empty`; a sealed v1 attempt is not retrofitted. This is a real implementation dependency, not permission to count an empty-policy or refusal-only run as the later useful-positive milestone.

## Separate Ponytail Review — complexity only

The need exists: current Backend commits launch before mutable packet construction. Reuse AtomicBundle, canonical encoding, protected historical provenance and ReadSet/RestartCheck rather than a second store, callback or privileged role-specific builder. One bounded result carrier and two fixed predicates are adequate; no plugin, DSL, migration framework or speculative abstraction is justified. Authentication, exhaustive set/absence checks and history reconstruction are necessary security work, not removable complexity. No code scaffolding or dependency was added. Later documentation maintenance should keep the prerequisite as the owner of seal semantics rather than letting two descriptions drift.

## Checks and limitations

- `elixir bin/check_docs.exs`: passed; **0 broken links**, AGENTS **469/800 words**.
- `git diff --check 927bfd990fd9427eae16b85738ae531d4452d32d..7cda7fe683034a71eedbfdeb9ec550b44a17926b`: passed.
- Exact detached HEAD, one-commit complete range, clean status and two-path scope checks passed. Both changed paths match the packet scope.
- Read AGENTS, index and main Q25, rule 3, R3/R4a, reviewed reconciliation/provenance designs and review 2, lane runbook, and suspended prototype checkpoint as data. Did not inspect or modify the moving prototype source.
- Static adversarial reasoning above is not executed protocol/red-control evidence. Per task, no runtime suite, scratch mutation, full gate, FR-08A rebind, sudo, host changes, integration or push was run.
- Residual risks: authenticated admissions/history/seal/import/check/result protocol is unimplemented; real macOS/Linux peer/UID isolation, attestor/tool separation, positive/restart/fault/red evidence remain required. Missing historical data may intentionally fence work. Nonempty check schema and terminal non-start proof remain separately gated. Model semantic error and prompt injection remain despite future identity isolation; the current recorded manual lane is not protected hostile-caller custody.

## Immutable lane-input note

The runtime's authoritative output-path override requires this file to be used instead of the task's alternate notes filename. This external file contains my complete review and will be supplied personally to `bin/foundry lane review` with the exact principal, candidate and `approved` verdict from main. I will not edit it after submission. The subsequent final response will report the verified lane receipt, status and archive digest; this note alone is not a committed verdict.
