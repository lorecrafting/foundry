# ML-PG-CONTRACT independent correction re-review

- Verdict: **approved**
- Exact candidate: `55d1ddfd0b146cbd8be9156ad8869cc2e0935f30`
- Base: `063a4a65161a9120291ab749586c8d5e8ad03c5e`
- Reviewer: `agent:codex-gpt-6-astra/review-ML-PG-CONTRACT-2`
- Date: 2026-09-26
- Checkout: clean detached `/private/tmp/ML-PG-CONTRACT-review-2`; reviewed the entire base-to-candidate diff and the five changed lines since the first review.

## Findings and disposition

No remaining blocking finding. R1 and R2 from the first review are closed by explicit semantic invariants. Approval applies only to this design candidate; it is not implementation or custody evidence.

### R1 closed — accepted-base equality

`docs/design/PORTABLE-GOVERNANCE-CONTRACT.md:17` pins both protected accepted commit and revision at admission and requires equality for any caller-supplied base. Line 27 requires ancestry and full scope against that pinned base, checks equality again at acceptance and promotion, and requires revised admission, a new attempt, fresh checks and independent review after movement.

Concrete attacks assessed:

- Accepted A, external A→B contains an out-of-scope change, C retains it and adds an in-scope change. Admission of B refuses because B differs from A. Admission of A followed by submission of C exposes the out-of-scope change in the full A→C delta and refuses.
- Ticket admitted at A, another ticket promotes A→B, stale candidate C descends from A. The accepted commit/revision no longer equals the pinned admission; acceptance or promotion refuses. Merely changing the expected-old argument cannot repair the stale evidence.
- An accepted-ref revision changes while the commit happens to remain equal. Revision equality still prevents reuse. The authorization transaction at line 31 revalidates these dependencies before issuing the claim.

### R2 closed — authorization and promotion exclusion

Line 31 makes atomic authority validation plus durable claim issuance the authorization point. Per-project exclusion spans claim issuance through terminal settlement/reconciliation, blocks later promotions and dependent policy/spec/acceptance changes, survives restart, and explicitly remains held for pending or unknown claims.

Concrete races assessed:

- A policy/spec change wins before issuance: atomic current-revision validation rejects the stale request. Claim issuance wins first: the dependent change cannot take effect until the claim settles. A separate pre-CAS reread is not relied on for authority.
- P claims A→B, updates Git and crashes before settlement. Q's B→C promotion cannot start; reconciliation observes exact B and its verified tree, settles P, and only then allows Q. Thus Q cannot produce a misleading third-value result for P.
- P crashes before CAS with ref A. Unknown status or restart does not release exclusion. Retry is permitted only once the previous issuer/channel cannot act. If the original writer completed during quiescence, the fixed expected-old CAS cannot overwrite that result; reconciliation must determine the observed outcome.
- A delayed duplicate A→B write after a successful promotion cannot roll back B→C: its expected A fails. Legal subsequent candidates descend from the accepted base.
- A third ref value or missing/corrupt object cannot count as success. The text retains a conflict/pending outcome; a third value requires operator investigation before exclusion release. Mere observation of uncertainty does not authorize another promotion.

The correction introduces no contradictory release rule. Detailed fencing, terminal failure proof and operator repair procedures still need implementation evidence in CUSTODY/ACCEPTANCE; this design does not claim those exist.

## Full-candidate scope and evidence audit

Lines 13 and 20 also close the earlier nonblocking schema ambiguities: retries bind authenticated actor, project and content, and trusted checks bind run identity plus exact candidate commit/tree. Lines 25–29 keep authenticated producer/reviewer separation, immutable custody, trusted policy and one fixed protected accepted ref. Lines 35–42 map CLI/skill and MCP clients to the same facts without native session/completion authority. Lines 5 and 46 clearly distinguish proposed semantics from the running lane and exclude spending, launch/session recovery and deployment claims.

Current-lane statements at line 9 were checked against `lib/foundry/manual_lane/cli.ex:128`, `:153`, `:166`, `:186`, `:248`, `:403`, `:497`; `backend.ex:68`, `:98`, `:147`, `:193`; `replay.ex:21`; `server.ex:242`; `lib/foundry/work_packet.ex:15`, `:44`; `lib/foundry/git_evidence.ex:33`, `:52`; and `lib/foundry/durable_store/protected/guards.ex:151`, `:164`, `:252`. They accurately describe recorded principals, mutable checkout validation, claimed packets, durable replay, empty checks and read-only external integration observation.

The provisioning choice at line 48 remains an operator decision before CUSTODY/ACCEPTANCE. A service-owned local bare repository with an actual isolation boundary is the minimum stated option. This does not authorize provisioning, select a seed, or certify a host's credentials/CAS behavior.

## Ponytail Review — separate complexity pass

Lean already. Ship. No machinery, dependencies or speculative abstraction to remove. The added predicates are necessary safety conditions, not implementation scaffolding.

## Checks and limits

- Exact HEAD verified; detached checkout clean before and after review.
- Entire diff: two scoped documentation paths, 49 added lines; no runtime or test changes.
- `git diff --check 063a4a65161a9120291ab749586c8d5e8ad03c5e..HEAD`: passed.
- `elixir bin/check_docs.exs`: passed, **0 broken links**; AGENTS.md **481/800 words**.
- Read packet, both review briefs, prior findings, standing agent brief, index, top-level README, applicable repair-plan milestone and runbook instructions.
- Static design review using the concrete traces above. No runtime race/fault injection, test suite, full gate, provider session or FR-08A rebind ran. No checkout files changed.

The reviewer personally records the verdict against the exact candidate and checks lane status after this note is written.
