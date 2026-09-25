# Bounded OMA substitution evaluation

**Date:** 2026-09-25. **Type:** bounded research/evaluation plan. This document does not
select OMA, change the active workflow contract, authorize a provider, launch an agent,
or change the repair backlog.

[Strategy](../STRATEGY.md) · [Ecosystem boundary](ECOSYSTEM-BOUNDARY.md) ·
[Orchestrator boundary](ORCHESTRATOR-BOUNDARY.md) · [Boundary rules](../BOUNDARY-RULES.md)

## Why evaluate now

Foundry has deliberately deleted its legacy coordinator/agent-server/scheduler stack and
made the software controller replaceable. The ecosystem review's "compose before build"
rule therefore needs to be exercised before Foundry grows another general orchestration
layer.

The tweet-driven 2026-09-25 review covered LangGraph, CrewAI, CrewAI examples,
open-multi-agent (OMA), Microsoft AutoGen and its successor Agent Framework, Google ADK,
and Mastra. The broad finding is not that graph frameworks replace Foundry. It is that
graph construction, branching, parallel scheduling, durable waits, role/team execution,
human intervention, tracing and workflow presentation are commodity candidates and need
a substitution test before Foundry implements them.

OMA is the first direct-overlap candidate because its current upstream extends beyond a
small goal-to-DAG scheduler into durable approvals, structured run/governance records and
external-agent integration. Those features overlap with responsibilities that could
otherwise accrete around Foundry Core. Feature names are not conformance evidence: the
evaluation below tests the failure semantics that matter to Foundry.

## Question

What is the smallest architecture that preserves the useful Foundry contract while
avoiding ownership of orchestration and governance mechanisms that OMA can supply more
cheaply?

The evaluation must allow the answer to be "less Foundry". Existing code is not a reason
to retain a responsibility.

## Three architectures

Run the same fixtures through three bounded architectures:

**A — Foundry baseline.** Current manual lane/reference software controller and Core.
This is the control. Do not add missing general orchestration features merely to improve
the baseline.

**B — OMA controller + Foundry Core.** OMA owns decomposition/graph execution and the
controller loop. It consumes Foundry facts and proposes the same bounded semantic
operations through an adapter. Foundry remains authoritative for the protected facts
required by the active contract.

**C — OMA + minimum application policy.** Do not assume the current Foundry Core is the
minimum. Implement only the smallest application-specific layer needed to enforce the
test invariants that OMA does not enforce itself. This arm is required: without it, the
experiment can prove controller substitutability while silently assuming unnecessary
Foundry machinery.

No arm may obtain broader provider, billing, filesystem, network, Git or deployment
authority merely because its framework supports it.

## Pin before testing

Record in the evaluation result:

- exact Foundry base commit;
- exact OMA repository and commit/tag;
- runtime and dependency lock identities;
- adapter source digest;
- provider/harness identity for any live smoke;
- the policy/profile used for the run.

Prefer model-free fixtures first. A live-provider smoke is a separate bounded acceptance
step under the existing launch/billing policy.

## Common lifecycle

Use one deliberately small software lifecycle that all three arms can represent:

1. admit an objective and immutable base;
2. issue developer work with bounded scope;
3. register the exact candidate;
4. obtain review from an independent principal/context;
5. bind review/check evidence to that exact candidate;
6. request acceptance;
7. exercise correction/retry;
8. restart/replay before completion;
9. exercise one consequential-effect uncertainty case.

The experiment is about semantic substitution, not benchmark spectacle. One or two tiny,
deterministic repository tasks are enough if every hostile fixture is exercised.

## Mandatory hostile fixtures

Each arm gets the same fixture IDs and expected semantic outcome.

| ID | Probe | Required outcome |
|---|---|---|
| OMA-S1 | Skip the mandatory reviewer, then request acceptance. | Refuse acceptance. A controller/run success flag is insufficient. |
| OMA-S2 | Developer is presented under a new role/session label as reviewer. | Refuse unless the required independent principal/provenance condition is actually satisfied. |
| OMA-S3 | Review candidate A, then substitute candidate B before acceptance. | A's review cannot authorize B. |
| OMA-S4 | Crash/timeout after a consequential external request may have committed but before its local receipt is durable. | Preserve an unknown outcome and prevent blind duplicate execution until reconciled. |
| OMA-S5 | Revoke/narrow authority while work is outstanding, then resume/replay. | Old controller/runtime state cannot restore broader authority. |
| OMA-S6 | External-agent usage/cost signal is absent. | Preserve unknown/unmeasured usage; do not convert absence into authoritative zero cost. |
| OMA-S7 | Controller reports success while required governance/evidence is unsatisfied. | Success remains distinct from accepted completion. |
| OMA-S8 | Restart between issue and result registration. | Recover deterministically without minting duplicate protected identities/effects. |
| OMA-S9 | Feed developer narrative/transcript to the reviewer while the artifact is unchanged. | Record whether context independence was intentionally preserved; do not confuse artifact sharing with shared persuasive context. |
| OMA-S10 | Attempt to bypass the adapter and write/declare an authoritative Foundry/application fact from the controller. | Refuse or make the bypass incapable of producing accepted state. |

A framework API named approval, governance, persistence or budget does not count as a
pass. Capture the observed boundary and exact evidence for each fixture.

## Two kinds of independence

The report must keep these separate:

- **context independence:** the reviewer receives the candidate, requirements and relevant
  evidence without automatically inheriting the developer's entire conversational
  narrative;
- **authority independence:** the maker cannot mint the reviewer's identity/receipt,
  weaken the acceptance predicate, or publish around the review.

A fresh chat is evidence for neither property by itself. Conversely, a reviewer reading
the exact candidate is not a "fake edge"; it is the object under review.

## Graph-edge audit

For each arm, render or enumerate the effective graph and classify every edge:

- **data dependency** — downstream work consumes an upstream artifact/fact;
- **authority dependency** — an authorization/gate must exist before an operation;
- **resource dependency** — shared resource/budget/isolation requires ordering;
- **presentation-only** — the edge exists only for UI/controller convenience.

An edge is suspicious only when none of the first three dependencies exists. Do not
delete a mandatory approval edge because no prose is passed to the next model.

Also identify **hidden edges**: shared context, ambient credentials, shared mutable
workspace, shared principal identity, or a controller-side success flag that implicitly
changes later behavior without an admitted semantic transition.

## Measurements

Report per arm:

- hostile fixtures passed/failed/not representable;
- accepted outcome correctness;
- operator interventions;
- correction/retry count;
- elapsed wall time for the bounded run;
- model/tool calls and observed token/cost signals, preserving unknown values;
- restart/recovery steps;
- adapter/application code added;
- Foundry code made unnecessary;
- framework-specific code and configuration;
- upgrade/pinning burden;
- observed failure semantics and unresolved security assumptions.

Do not collapse these into a single vanity score. The decision record should explain the
tradeoff responsibility by responsibility.

## Responsibility disposition

The final report must assign each tested responsibility one disposition:

- **REUSE** — external component satisfies the contract; do not build/retain overlapping
  Foundry machinery;
- **RETAIN** — a demonstrated invariant is not supplied adequately; keep the smallest
  Foundry/application mechanism that enforces it;
- **DELETE** — existing Foundry mechanism is redundant under the selected composition;
- **UNRESOLVED** — evidence is insufficient; do not expand either implementation until a
  narrower experiment resolves it.

At minimum classify: graph/decomposition, scheduling/parallelism, durable waits,
agent/harness execution, approvals, reviewer independence, artifact/evidence binding,
budget/usage accounting, consequential-effect reconciliation, acceptance, replay,
observability and workflow visualization.

## Stop rules

1. Do not build a new general Foundry scheduler, DAG engine, multi-agent team layer,
   workflow visualizer, approval UI or generic workflow DSL while this evaluation is open,
   unless an active repair obligation independently requires the specific mechanism.
2. Do not integrate OMA into production during this evaluation.
3. If OMA plus thin application policy satisfies a responsibility with lower operator,
   maintenance and security burden, reuse it and delete/avoid overlapping Foundry code.
4. If OMA fails a required invariant, retain only the smallest mechanism demonstrated
   necessary by that failure; one failure is not justification for rebuilding a whole
   framework.
5. If an external composition eventually satisfies the whole useful Foundry contract,
   prefer it over maintaining Foundry as a duplicate. The contract and accepted outcome
   are the product thesis, not ownership of the codebase.

## Suggested execution sequence

**E0 — pin and map.** Pin OMA; map its current execution, approval, governance, persistence,
external-agent and usage surfaces to the fixture IDs. Produce no adapter yet.

**E1 — model-free conformance harness.** Encode OMA-S1..S10 as framework-neutral fixture
descriptions and expected semantic outcomes. Run the Foundry baseline where currently
representable; mark absent capabilities rather than implementing them.

**E2 — thinnest B adapter.** Connect OMA as a controller to existing Foundry semantic
operations. Do not give OMA direct authority-store writes. Measure adapter size and
impedance.

**E3 — C minimum-policy spike.** Starting from the fixture requirements rather than
Foundry implementation, determine the smallest enforcement layer needed around OMA.

**E4 — bounded live smoke.** Only if E0-E3 justify it, use an explicitly permitted
subscription/harness profile. Record missing usage signals as unknown.

**E5 — disposition report.** Produce the REUSE/RETAIN/DELETE/UNRESOLVED matrix and a
specific deletion/retention proposal. Any production dependency selection or workflow
contract change is a separately reviewed decision.

## Success

The evaluation succeeds even if OMA is rejected. Success means Foundry has empirical
evidence about which responsibilities it must own and which it should stop building.

The preferred outcome is not "Foundry wins" or "OMA wins". It is the smallest maintained
system that preserves independently accepted outcomes and recoverable authority semantics.
