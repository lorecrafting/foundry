# C8 independent end-of-batch re-sweep

**Exact ref:** `ab7f6cd9b97643a76767aaa06b898a5a62f20a18`
**Checkout:** `/private/tmp/foundry-C8-milestone-sequence-resweep`
Read-only review, **not a lane verdict or landing authorization**.

## Review

- **Correct — no post-review semantic dependency change.** Read both supplied external diffs completely, including the truncated full-range continuation. They change only the repair plan, dogfood log and two archived reviews. The reviewed-candidate-to-gate delta archives evidence, replaces external references and updates status; it does not alter the dependency table.
- **Correct — acyclic useful-positive sequence.** `docs/REPAIR-PLAN.md:185–189` orders FOUNDATION → CANDIDATE → BROKER → CLOSURE → ACCEPTANCE. Foundation requires developer issuance/submission/sealing but forbids reviewer packets; candidate import/checks explicitly work without a broker; broker then proves the legitimate agent decision. Neither candidate nor broker requires completed custody closure.
- **Correct — original custody obligations remain owned.** Compared the old exact custody packet and correction review 5 with `docs/design/PORTABLE-CUSTODY.md:37–59` and the new plan. Foundation owns actual developer/operator isolation and original atomic packet recovery; broker owns isolated agent review; closure explicitly retains **all remaining** original host, endpoint/path/RPC, reviewer-positive, revocation, replay and restart obligations (`docs/REPAIR-PLAN.md:185–188`). No synthetic UID, refusal-only positive, mutable packet rebuild or operator impersonation substitutes.
- **Correct — no premature enablement or protected-role coupling.** Protected admission/seal semantics still require separate correction and independent review (`docs/REPAIR-PLAN.md:168–178`). Broker policy changes must work without new Core role literals (`:187`). Q24/Q25 retain host gates, unknown holds and operator-owned root/policy maintenance (`docs/batch-d/DOGFOOD-LOG.md:269–270`). No source, allowlist or frozen-contract change appears in either diff.
- **Correct — C7 evidence is kept ref-specific.** The updated account at `docs/batch-d/DOGFOOD-LOG.md:102,225–226` agrees with `/private/tmp/foundry-C7-main-push-evidence.md`: local 812-test gate at `08e05df`; final PR and main-push 809-test runs at `d4bbe90`. No C8 CI or protected-host acceptance is inferred. This verifies consistency with supplied historical evidence, not a fresh GitHub query.

### Ranked actionable finding

**P2 — live C8 handoff still lists the completed local gate as pending.**
`docs/batch-d/DOGFOOD-LOG.md:104,106,228` says “pending … gate/PR” and “finish C8 local gate.” The supplied provenance records `result: passed`, clean pre/post source and exact `ab7f6cd9b97643a76767aaa06b898a5a62f20a18`.

**Smallest fix:** in the next operator status update, record the local gate’s exact ref/provenance and leave PR CI/landing pending until separately evidenced. This is conservative pre-gate wording that became stale, not an authorization defect; it does not justify rerunning the gate or attributing its pass to a later documentation tip.

**Merge verdict: OK with notes** for this bounded documentation re-sweep. No P0/P1 finding. Parent retains fixes and landing.

## Historical-note false positives

- The archived sequence review’s stale-C7 finding describes its exact `8f9c26f` candidate, not today’s live handoff (`docs/batch-d/reviews/ML-PG-MILESTONE-SEQUENCE-DESIGN.review-1.md:7,13`). Preserve it.
- The archived packet review’s two P1s remain a **correction**, not packet-design approval. C8 resolves live ordering while retaining consumer-selection review as a prerequisite.
- The autonomous amendment’s older migration order is historical design text; its status explicitly assigns the active queue to the repair plan (`docs/design/PORTABLE-AUTONOMOUS-REVIEW.md:5,39`). It does not override Q25.
- Archived reviewers’ future-tense lane-recording statements are historical notes, not instructions or evidence that this re-sweep recorded a verdict.

## Separate Ponytail complexity pass

The custody split is justified by distinct achievable positives, not speculative architecture. It adds no bootstrap bypass, second authority store, policy interpreter or dependency. Keep the unresolved consumer-selection correction bounded; no architectural deletion requested.

## Evidence and limitations

Verified detached full HEAD through worktree metadata; `watchdog_diff` reported no working-tree changes before and after inspection. Source-tree equality before operator documentation is parent-provided evidence, not independently recomputed here.

Read the C8 provenance: clean exact ref, passing stages, pinned Elixir 1.20.3 / OTP 29.0.5 / ERTS 17.0.5. **812 tests is the supplied parent count**; no suite, gate, documentation checker, CI query, host action or lane command was run.

Residual gates remain: protected consuming-entry/seal semantics, terminal non-delivery/quiescence proof and typed R4a handoff, actual macOS/Linux identity/tool/restart controls, and independent implementation reviews. Same-provider correlated judgment and prompt injection remain disclosed risks.