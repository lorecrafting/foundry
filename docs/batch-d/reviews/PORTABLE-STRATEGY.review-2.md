# Portable governance strategy re-review

**Verdict: approved.** Exact candidate **`41401ead7bf5a5871f522d8b7ef8be3fa0294cb9`** closes all four findings from review 1. No remaining product-boundary blocker was found. This approves the reprioritization and its implementation requirements; it does not certify runtime enforcement or authorize a lane verdict.

## Finding disposition

| Review-1 finding | Disposition on this candidate |
|---|---|
| P1: observational integration substituted for protected promotion | **Closed.** `docs/REPAIR-PLAN.md:124–130,150–153` requires an authoritative accepted ref with an exclusive writer, refuses direct writes, isolates candidate check workers, and requires operator-triggered exact-candidate promotion through an issued claim and old-to-new ref CAS. Moved bases require fresh checks/review; a crash after the ref update requires effect reconciliation. These requirements preserve `docs/WORKFLOW-CONTRACT.md:737–749` without adding autonomous agent launch or activation. External refs remain observations. |
| P2: risk labeled prevented harm | **Closed.** `docs/strategy/VALIDATION.md:38–44` names the measured outcome prevented unsafe acceptance and separately requires observed follow-up evidence for downstream claims. |
| P2: completed-status contradictions | **Closed.** `docs/REPAIR-PLAN.md:134–136` preserves completed statuses and only leaves unresolved obligations open. `docs/batch-d/DOGFOOD-LOG.md:23–24` distinguishes integrated namespace/legacy cleanup from the remaining decompositions. |
| P2: O1 conflated with current kernel reuse | **Closed.** `docs/REPAIR-PLAN.md:154` names the manual-lane client seam. `docs/design/ORCHESTRATOR-BOUNDARY.md:948–951` explicitly permits existing `WorkflowKernel.decide/3` reuse and retains the separate O1 dependency and deferred autonomous lifecycle. |

C2 still precedes the portable milestone, with one rebind per split, one local batch gate and required PR CI before main fast-forward. The LokaCore comparison, second-real-client limitation, and deferred full-repair obligations remain intact. Detailed implementation design and exact-candidate review remain necessary for each packet.

**Nonblocking editorial nit:** `docs/REPAIR-PLAN.md:133–134` reads “Existing Remaining unresolved”. Delete “Existing”; this does not change the accepted meaning.

## Checks and limits

- Confirmed clean detached reviewer worktree, switched only that worktree to the exact candidate, and reviewed all five changed paths since `8b49bb5`, including the preserved first report.
- Rechecked the binding integration contract against the revised promotion/custody requirements.
- `elixir bin/check_docs.exs`: **0 broken links**.
- `git diff --check da3bb3c54d19b0774f35ee0a4280b75519b1ec20..41401ead7bf5a5871f522d8b7ef8be3fa0294cb9`: **passed**.
- Separate Ponytail Review of the correction: **Lean already. Ship.** No additional machinery or safe substantive deletion; **net: -0 lines possible**.
- Final reviewer `git status --porcelain=v1`: **empty**. No candidate files or integration worktree were edited. Only this report outside the repository was written.
- No full gate, implementation tests, CI, provider session, lane command or product pilot ran. Approval is a strategy/document verdict at the named revision.
