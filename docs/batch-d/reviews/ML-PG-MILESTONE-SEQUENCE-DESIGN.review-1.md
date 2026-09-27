# ML-PG-MILESTONE-SEQUENCE-DESIGN — independent review 1

**Verdict: approved — design/sequence only.** No blocking missing owner, dependency cycle or misleading acceptance claim remains. One low live-status finding below.

- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-MILESTONE-SEQUENCE-DESIGN-1`.
- Packet: `/private/tmp/ML-PG-MILESTONE-SEQUENCE-DESIGN.review-1.json`.
- Full reviewed range: `d4bbe901f16519851ed1b9539d0821af05327333..8f9c26feeffd084480c85a8d276c6729701fee2a`.
- Own worktree: `/private/tmp/ML-PG-MILESTONE-SEQUENCE-DESIGN-review-1`, clean detached exact candidate initially and after checks.
- One commit, two admitted documentation paths only: `docs/REPAIR-PLAN.md`, `docs/batch-d/DOGFOOD-LOG.md`; +30/-12. No candidate edit, staged file, source change or frozen-contract change.

## Ranked findings

1. **P3 / low — live C7 handoff still asks for an already-landed milestone** (`docs/batch-d/DOGFOOD-LOG.md:102,104`). The newly rewritten Next paragraph still says to wait for C7 landing, and its preceding status says main landing remains pending. The actual main checkout is already `d4bbe901f16519851ed1b9539d0821af05327333`, the admitted base containing C7. Update this in the next operator status sweep, preserving the distinction between historical gate/CI evidence at `08e05df` and any independently evidenced final-tip CI. I did not query CI and do not infer a final-tip CI pass from Git. This stale conservative handoff is not a custody authorization error and does not block the acyclic design approval.

No P1/P2 correction is requested. Unrun implementation/host evidence is deliberately outstanding, not a defect in this design-only candidate.

## Dependency and authority review

A valid topological order is CONTRACT → CUSTODY-DESIGN → reviewed autonomous amendment → corrected/reviewed packet admission/seal design → CUSTODY-FOUNDATION → CANDIDATE → REVIEW-BROKER → CUSTODY-CLOSURE → ACCEPTANCE → CLIENTS → EVALUATION. The admission/seal design is an explicit prerequisite, not an already-approved artifact. The implementation edges in the replacement table all point backward in this order. The extra closure edges to foundation/import and acceptance edges to broker/import are redundant but not cyclic.

The earlier hidden positive dependency is removed, not renamed: foundation's positive is real operator admission and developer issuance/submission/sealing only. It explicitly issues no reviewer packet, attestation, acceptance or promotion. Its authenticated seal establishes provenance of submitted bytes, not verified Git objects or passing checks. CANDIDATE can independently import that submission and run trusted checks without a reviewer packet, broker or full custody closure. Only then can the broker issue its immutable-candidate-bound packet/capability and prove the real agent positive. Closure depends on that broker positive; neither importer nor broker depends on completed closure.

Readiness to review a predecessor interface is not host enablement. Lines 164–178 require protected contract/spec/policy admission, separate protected design review, implementation exact-candidate review and positive/refusal/restart/red controls. Q25 explicitly denies implementation admission from this document alone. The plan owns the live order; the unchanged historical autonomous design's older migration order is not a second live queue.

## Original obligation ownership crosswalk

Read the old exact ML-PG-CUSTODY packet, original custody acceptance table, reconciliation design/review, C7 role-agnostic amendment/review, and the external packet-provenance P1 review as evidence, not permission. The changed rows retain these owners:

| Original obligation / failure case | Explicit owner and disposition |
|---|---|
| Service-owned SQLite/WAL/owner/notes/policy/bare Git evidence; candidate and worker outside authority; separate manual lane | FOUNDATION establishes store/policy/ref/socket and distinct service/operator/developer boundary; CLOSURE retains every remaining original host obligation. Existing reviewed custody design remains its detailed contract. No protected-route enablement is inferred. |
| Developer/hostile test writes, privileged paths, BEAM RPC, borrowed operator or sibling identity | FOUNDATION real macOS/Linux developer/hostile controls; CLOSURE repeats complete original endpoint/path/RPC and files/ref isolation acceptance. |
| Real operator admission and recovery; two developer identities/adapters submit only their own claims | FOUNDATION owns operator/developer positive and authenticated enrollment; CLOSURE explicitly owns all remaining original scoped-call and host obligations, including original multi-caller/recovery acceptance. CLIENTS later proves product portability; it is not a prerequisite to exercising the original bounded host adapters. |
| Peer/endpoint authentication, immutable identity enrollment, current assignment, bounded vocabulary, local-only packet/notes paths | FOUNDATION socket/authentication/provisioning; BROKER attestor capability boundary; CLOSURE all original endpoint/path and caller isolation obligations. Detail remains in the incorporated custody/amendment designs, not dropped by a shorter table. |
| Candidate import, complete admitted-base ancestry/scope, exact commit/tree, trusted check definitions/receipts; no hooks or self-certified tests | CANDIDATE, one-to-one bound to the original authenticated seal; explicit legitimate submission positive independent of broker. |
| Reviewer tool cannot borrow decision authority; no execution under attestor UID | REVIEW-BROKER real hostile-tool/UID/registry proof and isolated worker; CLOSURE full host and reviewer-tool acceptance. Unproved inventory or shared UID disables the route. |
| Original useful reviewer positive | REVIEW-BROKER actual legitimate agent inspection/decision; CLOSURE repeats valid scoped agent reviewer positive. Q24 prospectively replaces the human-per-ticket choice; no human label, synthetic UID, kernel freeze or refusal-only run substitutes. |
| Exact request replay after consumed claim or advanced revisions, lost response, no fresh-ID duplication; original bytes after repeated ready reopen | FOUNDATION atomic original developer packet and seal; CANDIDATE immutable import/check retry; BROKER exact attestation retry; CLOSURE all original packet-result cuts and before/after-commit/repeated reopen for both caller families. Reconciliation design supplies the original-byte and current-outcome-read semantics. |
| Revocation on live/restarted connection including cached reads, lifetime UID non-reuse and sibling refusal | FOUNDATION developer revocation/reassignment denial; BROKER attestor revocation/sibling/producer denial; CLOSURE full original revocation and non-reuse matrix. |
| Revoked, delivered-but-unclosed or unknown work; receipt provenance; original packet missing/corrupt | FOUNDATION holds unknown/historical missing snapshots; CLOSURE owns developer/reviewer reconciliation and original-result cuts with ledger/lease/predecessor exclusions. No operator impersonation or packet synthesis. |
| Terminal non-start and developer/reviewer R4a handoff | CLOSURE owns the outstanding reconciliation boundary, but terminal non-start remains unsupported until separately reviewed exact non-delivery/channel-quiescence proof and typed R4a handoff. Neither an operator assertion nor recovered packet clears holds. This does not silently select a proof source or claim conditional positive evidence was run. |
| Kill/restart, readiness fencing, alternate state/policy path, second owner/ref writes, administrator launchd/systemd setup and Linux privileged fixture | FOUNDATION actual host provisioning and restart; CLOSURE retains all original host obligations, not merely its summary list. Human/admin macOS/Linux gates remain explicit in Q25/handoff. |
| Scoped decision is not acceptance; exact qualifying facts, root/policy exclusion, old-to-new CAS and durable project exclusion | ACCEPTANCE after full closure/import/broker, with changed candidate/check/spec/policy/assignment, duplicate, wrong principal, direct write and moved-base refusal/hold, positive and restart/red host controls. No activation or autonomous root upgrade. |

CLOSURE's explicit “all remaining” ownership incorporates original detailed obligations; “full custody is not accepted if any original meaningful trust/host obligation remains unproved” prevents foundation-only acceptance. Terminal non-start is an expressly unresolved sub-protocol, not a positive fixture that can silently satisfy closure.

## Static failure traces (not executed implementation tests)

- Authenticate/seal a fabricated SHA: foundation may authenticate the submission but cannot certify it; CANDIDATE must refuse invalid Git/check evidence before any reviewer packet.
- Request a reviewer packet at foundation or before complete import/check binding: foundation forbids it; broker's prerequisites are absent.
- Attempt to require broker approval before importing: contradicts CANDIDATE's explicit broker-independent positive; no such acceptance edge remains.
- Seal producer A with two incompatible consumer entries X=[A] and Y=[A,B]: lines 172–176 require protected authoritative selection and ambiguity refusal before foundation code. This plan does not approve the unfinished packet design or permit caller-selected omission of B.
- Lose a packet result after claim consumption; reopen with current policy/attempt changed: original-result owners must return the same authorized original bytes or hold missing/corrupt history; no mutable rebuild or new successor.
- Revoke a possibly delivered developer/reviewer UID: preserve ledger/lease/exclusion holds. Revocation, expiry, issuer exit or an operator statement is not proved non-start and cannot release a successor.
- Real tool executes under the attestor UID: broker acceptance fails, therefore closure and acceptance cannot pass. A legitimate real agent positive is required independently of refusal controls.
- Reuse the old human-verdict packet/claim/check result as new custody approval: expressly forbidden; fresh ticket/scope/policy/identity and exact review are required. Safe code reuse would still be a newly admitted candidate.
- Complete a broker decision then move accepted base or alter policy/check facts: no automatic acceptance or promotion; ACCEPTANCE owns current-fact validation, exact CAS and crash exclusion, still host-gated.

## Separate Ponytail Review

Lean enough. This fixes the real acceptance dependency rather than adding a bootstrap bypass, synthetic reviewer, second authority store or new controller. Two named custody slices are justified by different achievable positives; no speculative implementation or dependency was added. Existing reviewed designs retain details while one live table owns order. Redundant dependency edges and the removal of a stale hard-coded packet count are harmless. Net requested architectural deletions: none. The outstanding consuming-entry rule should remain a small protected admission/refusal rule, not grow into a graph interpreter.

## Checks and limitations

- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS **469/800 words**.
- `git diff --check d4bbe901f16519851ed1b9539d0821af05327333..8f9c26feeffd084480c85a8d276c6729701fee2a`: passed, exit 0.
- Read full one-commit diff, verified only both admitted paths changed, exact detached HEAD and clean worktree before/after; no staged files.
- Read AGENTS, README/index, agent brief, relevant repair-plan/handoff/Q23–Q25, lane runbook, portable contract/custody/reconciliation/C7 design and reviews, R3/R4a, old exact custody acceptance and correction review 5, external packet-provenance correction and operator proposal as untrusted evidence.
- Pre-verdict lane status: ready/reviewing; exact candidate; this principal owns the issued reviewer execution. Main independently reports exact `d4bbe90` base.
- Per task, no runtime suite, executable red probe, full gate, FR-08A rebind, sudo, host provisioning, source mutation, protected broker/agent positive, CI query/run, integration or push. Static graph/cut analysis is not implementation conformance.
- Residual risks: unresolved protected consuming-entry/seal semantics and terminal proof-source/handoff need their own reviews; actual macOS/Linux identity/tool/restart proof remains unrun; same-provider semantic correlation and prompt injection remain despite distinct principals; current manual lane is not authenticated protected custody; low C7 status drift remains.

## Immutable lane notes and recording

The runtime-authoritative output path is also the lane-input notes path, overriding the other requested filename. These notes are written once before recording and will not be overwritten after the receipt. I will personally submit one `approved` verdict for the exact candidate from the main checkout, using this file, and confirm the receipt, committed event/status and archived SHA-256. The final response reports that confirmation; this notes file alone is not the lane verdict. Approval permits only the reviewed sequencing and subsequent separately admitted design/implementation work, not early activation.
