## Review

**No high/medium issue found. One low-priority documentation finding.** This is an independent end-of-batch re-sweep, not a lane verdict or installed-custody approval.

### Scope and evidence

Reviewed the complete supplied diff for `927bfd990fd9427eae16b85738ae531d4452d32d..b8ee85ffc7dccf17b4f522bd58fc9cd66020d761` and the supplied `92d678a..b8ee85f` comparison. Nine documentation paths changed; no source, tests, frozen workflow contract or architecture allowlist changed.

Read AGENTS, index, portable repair-plan section, R3/R4a, amendment, both archived independent reviews and separate operator follow-up. Direct HEAD reads and initial/final working-tree checks confirmed the checkout remained clean and detached at the required full SHA.

### Correct

- **No material post-review design alteration:** amendment changes after `92d678a` update approval/integration history at `docs/design/PORTABLE-AUTONOMOUS-REVIEW.md:5,9,39`; authority, bindings, recovery and host-gate requirements remain unchanged.
- **Role-neutral mandatory authority remains explicit:** authenticated producer provenance, protected attestor issuance, inequality against every protected producer, non-waivable checks and bounded predicates appear at `docs/design/PORTABLE-AUTONOMOUS-REVIEW.md:13–15,25`. Workflow labels cannot confer authority.
- **Containment and host gates remain mandatory:** distinct attestation-only identity, no executable candidate tools under that identity, actual macOS/Linux hostile-tool/useful-positive/restart controls and scratch red controls remain at `:17–19,33`.
- **Migration and dependencies agree:** `docs/REPAIR-PLAN.md:169–175` and amendment `:39` require re-admitted custody, then broker, candidate/check, acceptance, clients and evaluation. Old packet authority is not recycled.
- **Historical approvals are distinguished correctly:** `docs/batch-d/DOGFOOD-LOG.md:102,223–224` separates older-criteria `cfb2de8` approval from full-range `92d678a` approval. Archived “unintegrated” wording is historical, not a current integration claim. The operator follow-up explicitly is not an amended verdict.

### Finding

**P2 — Stale design-review status in the live index.**
`docs/README.md:92` says “independent review and real-host gates outstanding,” but the linked amendment records completed independent design approval at `docs/design/PORTABLE-AUTONOMOUS-REVIEW.md:5`, corroborated by `docs/REPAIR-PLAN.md:169`.

**Disposition:** non-blocking documentation correction. Replace that clause with “design independently approved; implementation review and real-host gates outstanding.” Leave archived reviews untouched.

### Prior checks and unknowns

`docs/batch-d/DOGFOOD-LOG.md:102` correctly attributes:
- Local C7 gate: **812 model-free tests at `08e05df`**.
- Initial PR #26 Linux run `36305787463`: **809 tests at `08e05df`**.
- Final-tip CI and main landing: **pending**, not passed.

These are supplied historical evidence, not checks rerun or remotely authenticated here. No commands, lane receipts, gate/rebind, installation, launch or promotion were performed. Actual containment, atomic recovery and autonomous acceptance remain unproved; semantic prompt injection and correlated model errors remain disclosed risks.

## Separate Ponytail complexity pass

Appropriately bounded: fixed predicates, existing custody/result mechanisms and exact Git CAS; no new policy language, controller or dependency. No simplification should remove mandatory lineage or recovery checks. Only the stale index wording needs cleanup.

**Merge verdict: OK with notes for this documentation range; final-tip CI remains pending. No authorization of installed custody or autonomous acceptance.**