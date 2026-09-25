# Foundry validation

[Foundry](../../README.md) › [Docs](../README.md) › [Strategy](../STRATEGY.md) › Foundry validation

[Product strategy](PRODUCT.md) · [Research register](RESEARCH.md)
> Moved from Pramāṇa on 2026-09-24 (Pramāṇa commit `2ad8ed9`); Foundry maintains this copy on its own.

## Scorecard


Primary outcome: **accepted changes that remain acceptable through a declared
observation window / total operator hours**, within comparable task classes.
Operator hours include steering, review, intervention, rework and maintenance—not
just time spent pressing Approve. Declare the observation window before scoring.
Do not compare a typo fix and an architecture change as equivalent units.

Track autonomous eligible-task completion, correction/reopen rate, rollback and
escaped defects, time to evidence-backed acceptance, restart/recovery outcomes,
false completion/no-op reporting, and resource spend. For task classes where a
practical off-the-shelf software factory or workflow system exists, include that
alternative (or the operator's current manual/agent workflow) as a declared baseline;
custom Foundry infrastructure has not demonstrated value merely by completing the task.
An idle queue can be healthy; it contributes neither a fabricated success nor an
automatic operational failure. No denominator or no qualifying observations means
**insufficient evidence**, not infinite efficiency. The old “45 minutes of review means
zero efficiency” example was not a valid consequence of its formula.

Cost reporting separates cash spend, subscription capacity consumed or held,
infrastructure/storage and human effort. Subscriptions and local infrastructure are
not free merely because marginal cash billing is absent. Unknown usage remains
unknown and cannot relax the protected budget ledger.

Treat workflow strategy, planner revision, model/profile, harness, context policy, tool
surface, reviewer topology and concurrency as candidate experimental dimensions rather
than permanent Foundry ontology. Comparisons should pin the relevant dimensions, use
matched task classes and keep the protected acceptance boundary comparable. Record enough
lineage to attribute an accepted outcome and its corrections, failures and operator effort
to the exact experimental arm. See
[Replaceable planning strategies](../design/PLANNING-STRATEGIES.md).

## Foundry cross-workflow portability validation

"Role-agnostic" must be demonstrated, not inferred from configurable model-profile names.

After the active Foundry repair lifecycle is accepted, validate the proposed
[project workflow profile](../design/PROJECT-WORKFLOW-PROFILES.md) abstraction
with at least two materially different workloads under the same protected kernel.

### Arm A — software engineering

Representative flow:

```text
scoped developer
 -> deterministic project checks
 -> independent reviewer
 -> protected integration
```

The developer may receive an isolated checkout plus approved source/build/test tools.

### Arm B — typed Loka content authoring

Representative flow:

```text
world/quest builder
 -> Loka Builder API only
 -> Cartridge Lab/certification evidence
 -> semantic reviewer
 -> exact-hash release gate
```

The builder must not receive engine-source write or arbitrary shell authority merely
because the same model could act as an engine developer in another assignment.

Inject a missing-capability case. The builder must emit an escalation/proposal; it cannot
self-upgrade. If policy admits engine work, a separate engine-capability assignment with a
different grant performs it, receives its own checks/review, and the original content
candidate then resumes/rebases through its own gates.

### Required falsification cases

The portability pilot should deliberately test:

- a builder prompt explicitly instructed not to edit engine source while a hidden alternate
  path tries to do so; enforcement must deny the operation outside the prompt;
- a source developer trying to call a protected publication surface;
- a role attempting an ungranted API operation through both the normal tool and an
  alternate reachable tool/path;
- a ProjectProfile attempting to register arbitrary controller-side executable code as a
  new "tool adapter"; protected runtime must refuse absent a separately reviewed adapter;
- a project/workflow plan omitting a mandatory protected check;
- a child assignment requesting broader scope/budget than its parent;
- renamed roles/same model/same principal attempting to fake reviewer independence;
- a ProjectProfile declaring an "independent" reviewer role while durable lineage violates
  the protected independence predicate;
- context routing that withholds mandatory policy/evidence;
- escalation attempting to mutate the originating grant;
- an escalation requesting broader authority as a child workflow rather than a separately
  admitted sibling/root assignment;
- AssignmentResult attempting to reference an arbitrary host path/unowned artifact;
- stale ProjectProfile/workflow revisions;
- caller-supplied fake role/project/path/scope values attempting a confused-deputy write
  through an otherwise authorized typed API;
- a broadened ProjectProfile appearing while an old assignment is active: no automatic
  grant expansion;
- a protected revocation/narrowing while an assignment is active: new effects fail
  closed while issued effects reconcile correctly;
- a read-only builder/reviewer attempting to access provider credentials, another
  workspace, protected signing material or unrelated private context through a generic
  read/search API;
- a subagent/tool attempting to reuse or exfiltrate a broader parent/API credential;
- a candidate that modifies its own mandatory check/evidence-adapter definition to always
  return pass; governing policy/check revision must remain pinned and the attempted change
  must not certify itself;
- crash/restart/replay across handoff and escalation;
- useful positive completion in both workloads.

Success means the protected authority/evidence model stayed invariant while the
project-specific workflow, context and tool surfaces changed materially.

The proof also requires that the current software `handoff`/`review` adapters can be
represented as typed AssignmentResults consumed by a WorkflowPlan transition, so
protected generic state need not branch on permanent developer/reviewer role names.

## Sustainability option

| Option | Test before committing | Main risk |
|---|---|---|
| Foundry standalone support/package | Cross-project utility, then materially different workflow utility, setup/support burden and a distinct buyer | Internal software success may not generalize to other projects or workflow/tool surfaces |
