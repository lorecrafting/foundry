# C4 full-batch re-sweep

- Reviewer: fresh OpenAI GPT-6 Astra batch reviewer, distinct from both ticket reviewers.
- Reviewed HEAD: `717571148a0824db0de7dff1d5be2f020458faaa`.
- Full delta: `063a4a65161a9120291ab749586c8d5e8ad03c5e..717571148a0824db0de7dff1d5be2f020458faaa`.
- Checkout: detached `/private/tmp/foundry-C4-resweep`, clean before and after review.
- Scope: all five changed documentation files, 192 insertions and 3 deletions, including both archived reviews and the operator log. No repository edits.

## Findings

**No actionable findings in the reviewed batch.** This is a design and evidence-consistency review, not proof of implemented portable acceptance.

### Accepted base and promotion

The design at `docs/design/PORTABLE-GOVERNANCE-CONTRACT.md:17` and `:27` pins the protected accepted commit and revision at admission, requires any supplied base to equal it, checks the entire admitted-base-to-candidate scope, and requires equality again at acceptance and promotion. An external A→B containing unaccepted work cannot be hidden by admitting B while the accepted ref is A. A competing accepted-base advance requires revised admission, a new attempt, checks and independent review. These obligations agree with `docs/WORKFLOW-CONTRACT.md:737` and the portable milestone rows in `docs/REPAIR-PLAN.md:146`.

Line 31 makes atomic authority validation and durable claim issuance the authorization point. The durable project exclusion blocks dependent policy/spec/acceptance changes and other promotions until settlement or reconciliation. Thus a policy change cannot slip between authorization and Git CAS, and a second promotion cannot obscure a first promotion that updated the ref but crashed before settlement. Old-ref retry requires the previous issuer/channel to be unable to act; third values and missing/corrupt objects cannot establish success. Fixed old-to-new CAS and exact reviewed commit/tree semantics preserve the full workflow contract's integration invariants.

### Current lane and authority claims

The present-boundary paragraph accurately describes current source: explicit principal strings and resolved admission bases (`manual_lane/cli.ex:128`, `:153`, `:166`, `:186`); claimed packets and durable receipts (`backend.ex:68`, `:98`, `:147`, `:193`); packet identities (`work_packet.ex:15`, `:44`); committed-event replay (`replay.ex:21`); recorded-principal independence (`durable_store/protected/guards.ex:151`, `:164`, `:252`); mutable clean-checkout/HEAD/ancestry observation (`git_evidence.ex:33`, `:52`); seeded empty checks and refusal of nonempty checks (`server.ex:242`, `cli.ex:403`); and read-only patch-equivalence integration observation (`cli.ex:248`).

The new design explicitly separates proposed authenticated custody, trusted checks and protected promotion from those existing capabilities. Its two client mappings introduce no controller-specific protected fields. The log calls C4 reviewed design and does not turn `lane integrated`, a reviewer verdict, the existing gate, or client completion into protected acceptance. Spending, agent launch/session recovery and deployment remain excluded, consistent with the approved portable milestone.

The integrated contract and index are byte-identical to the reviewed `55d1ddf` candidate. The only changes after the gate's `f3cbf99` source are the operator log and two archived reviews. The review chain retains the original counterexamples and accurately identifies their correction, without treating historical approval as implementation evidence.

### Operator's local bare repository choice

Q22 in `docs/batch-d/DOGFOOD-LOG.md:242` selects the design's Option A: a dedicated service-owned bare repository under an actual OS access boundary. This matches the written tradeoff and provides a concrete first exclusive-writer deployment without requiring proof of a Git host's custom namespace and expected-old update behavior. Bare storage alone is insufficient; Q22 correctly retains isolation tests and an operator-selected provisioning seed as CUSTODY obligations. The design retains the costs of explicit backup and separate public-main synchronization. No repository provisioning or custody proof is claimed. The log identifies this as an operator default under the human's continue instruction, not a newly invented human decision.

## Ponytail Review — separate complexity pass

Lean already. Ship.

## Checks and limits

- `git diff --check 063a4a65161a9120291ab749586c8d5e8ad03c5e..HEAD`: passed.
- `elixir bin/check_docs.exs`: passed; **0 broken links**, AGENTS.md **481/800 words**.
- Exact reviewed design/index comparison against `55d1ddfd0b146cbd8be9156ad8869cc2e0935f30`: no differences.
- Inspected the existing C4 provenance: it records `passed`, clean source and postflight at `f3cbf995bebdbc33b8c1a9ddb79d6c2bca469916`, and matching Elixir 1.20.3 / OTP 29.0.5 / ERTS 17.0.5. The log's 812-test count is an operator-reported prior result; this review did not rerun or independently recount it.
- No tests, gate, provider session, custody attack, fault injection, FR-08A rebind, provisioning or lane verdict ran. No live lane database or remote CI was queried. The review checks the recorded operator authorization claim for consistency; it does not independently authenticate the earlier human instruction.
- Remaining implementation evidence belongs to CUSTODY, CANDIDATE and ACCEPTANCE: actual principal isolation, hostile check containment, immutable object custody, authority transaction/exclusion enforcement and crash reconciliation. The batch does not claim these are complete.
