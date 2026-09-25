# How Foundry works

[Foundry](../README.md) › [Docs](README.md) › How Foundry works

This page explains each of Foundry's mechanisms in plain terms, in the order a ticket
meets them, and then defines the vocabulary. Each section ends with the one document to
read next. For what Foundry is and why it exists, read the [overview](../README.md) first.
This page describes the code on `main`. Where it and the code disagree, the code wins,
and this page needs a fix.

## The one idea

Foundry separates **doing** work from **deciding what counts**. Agents do work anywhere,
with any model or tool. The only things that count are **committed events** in one SQLite
store. Core writes those events only after a pure kernel has checked each command against
the current state. Everything else is observation: logs, transcripts, process exits, an
agent saying "done". Observation can explain work but cannot change what counts
([boundary rule 9](BOUNDARY-RULES.md)).

```text
  command ──► CLI (inert transport) ──► Workflow kernel (pure: decide) ──► Core (durable store: commit)
                                              │                                   │
                                        refusal atom                     committed events = truth
                                                                                  │
                                                      lane status / lane log (read-only projections)
```

## 1. Command transport: arguments are data

`bin/foundry` never evaluates what you type. It packs your arguments into a bounded,
versioned JSON envelope, encodes that as base64, and sends one fixed call,
`Foundry.CLI.RPC.run/1`, to the running release. The daemon rejects malformed, oversized,
duplicate-key, non-UTF-8 and NUL-containing payloads, and it refuses any command that is
not a `lane` command. This is ticket FR-02's containment. The release's general `rpc`
evaluator is still not a safe public boundary, so keep access local. FR-15a replaces it.

Code: `bin/foundry`, `lib/foundry/cli/rpc.ex`. Next: [lane runbook §2](batch-d/LANE-RUNBOOK.md#2-start-and-stop).

## 2. The manual lane: today's only ingress

The lane is the part of Foundry that runs today. It covers one ticket from admission to
"ready to integrate", and it **launches nothing**. The operator (a human or an LLM
session) carries each work packet to an agent by hand. The lane has one daemon
(`ManualLane.Server`), started by `bin/foundry-lane start` with `FOUNDRY_MANUAL_LANE=1`.
A node started without that flag starts no children.

The phases of one ticket:

| Step | Command | What Foundry checks and records |
|---|---|---|
| Admit | `lane admit` | the base ref resolves in the repo; records scope and acceptance criteria |
| Developer packet | `lane packet --role developer` | issues one **effect** for a named principal and spends one allocation unit |
| Submit | `lane submit` | the checkout is clean, its `HEAD` is the candidate, and the base is an ancestor |
| Reviewer packet | `lane packet --role reviewer` | the reviewer principal is independent of the developer (see §5) |
| Review | `lane review --verdict approved\|correction\|rejected` | the review binds to the exact submitted candidate; the notes body is archived by digest |
| Settle | `lane settle` | closes a packet that never ran (`non_started`) or whose fate is unknown (`unknown`) |
| Integrate | manual `git cherry-pick`, then `lane integrated` | read-only: is every commit of `base..candidate` in the ref? |

`approved` leads to `ready_to_integrate`. `correction` queues the ticket for a new
developer packet. `rejected` is terminal. Integration itself is plain Git outside Foundry
until FR-14.

Code: `lib/foundry/manual_lane/`, `lib/foundry/work_packet.ex`, `lib/foundry/git_evidence.ex`.
Next: [lane runbook §3](batch-d/LANE-RUNBOOK.md#3-one-ticket-phase-by-phase). Design and
accepted risks A1–A6: [thin lane design](batch-d/THIN-LANE-DESIGN-2026-09-23.md).

## 3. The workflow kernel: pure decisions

`Foundry.Workflow.Kernel` is a pure reducer. It does no I/O and reads no clock, random
source, Git or configuration. Given the current state and a command, it returns either a
refusal or a **proposal**: plain data naming the events to commit and the effects to
request. It never writes anything itself, and it never references the store
([boundary rule 2](BOUNDARY-RULES.md)). The properties that make it trustworthy:

- **Closed vocabulary.** Only enumerated event types, each with an exact payload shape.
- **Source-state guards.** Every event names the phase it may apply to. Anything else is
  refused, so a ticket cannot jump phases or move backwards.
- **No creation by projection.** Only admission creates a ticket, so a terminal state is
  reachable only through its lifecycle.
- **Closure.** Every post-state is re-validated, so no handler can write a state the
  kernel would later refuse to read.

The software-specific rules (developer, review, checks, integration) live in
`workflow/kernel/software/`, the reference controller. The protected core does not
depend on them.

Code: `lib/foundry/workflow/`. Next: the kernel's moduledoc, then the
[workflow contract](WORKFLOW-CONTRACT.md) that it is tested against.

## 4. Core: the durable authority store

Core is `lib/foundry/durable_store/`. `DurableStore.Gateway` owns the only SQLite
connection. It runs in WAL mode with `synchronous=FULL` and a single owner across OS
processes. For each command it:

1. derives the command's identity from the actor and the complete canonical request;
2. returns the stored result if that exact command was already committed (**idempotency**:
   rerun anything after a timeout or crash), and reports a conflict if the same ID arrives
   with a different request;
3. commits the input, the result, the events and the projections in one transaction, and
   replies only after `COMMIT` succeeds.

**Protected operations** are policy, allocation ledger, reservations, effects, receipts and
leases. They enter only through `Gateway.protected_command/4` and `Gateway.atomic_bundle/4`,
which need a capability the kernel never sees. So a kernel proposal can ask for an effect
but cannot mint budget or forge a receipt. The **allocation ledger** holds the budget. The
seed policy grants a fixed number of developer and reviewer starts for the whole store,
and an exhausted store refuses new packets with `allocation_unavailable`.

Code: `lib/foundry/durable_store/`. Next: [durable store](DURABLE-STORE.md), then the
generated [schema reference](DURABLE-STORE-SCHEMA.md). The budget ledger has a formal
model: [ledger spec](../spec/ledger/README.md).

## 5. Principals and reviewer independence

Every packet names a **principal**, for example `agent:claude-opus-5-5/dev-ML-42`. Only the
principal that was issued an effect may submit, review or settle it. The seeded policy
declares the reviewer role independent of the developer role, so Core refuses a reviewer
packet whose principal issued a developer effect on the same attempt, with
`principal_not_independent`. Core enforces this, not a controller that might forget to
check.

This is the honest limit: until execution isolation lands (FR-15aB), principals are
**recorded, not authenticated**. Independence is only as real as the operator's choice of
a fresh reviewer on a different model. The lane is built to make that choice visible, not
to prove it.

Next: [reviewer-independence design](fr-08/FR08B-REVIEWER-INDEPENDENCE-DESIGN-2026-09-23.md),
[runbook §4](batch-d/LANE-RUNBOOK.md#4-principals).

## 6. Refusals, recovery and uncertain outcomes

- **Refusals are stable atoms**, for example `wrong_source_phase`, `candidate_mismatch` or
  `git_evidence`. A refusal commits nothing to the ticket, and `lane log` still shows it.
  Each atom and its remedy is in [runbook §5](batch-d/LANE-RUNBOOK.md#5-refusals).
- **Crash recovery is fenced.** After an unclean stop, every command reports
  `gateway_recovery` until the operator confirms that no other process owns the store
  and runs `lane recover --evidence "…"`. Foundry does not guess that the previous owner
  is dead.
- **Uncertain outcomes are never retried blindly.** An issued packet whose fate is unknown
  is settled as `unknown`. That is permanent: its units stay held and the ticket is
  abandoned. `non_started` needs the operator's attestation that the issuer is gone and
  the channel is quiet. The attestation is recorded but not proved. FR-10 owns real
  reconciliation ([FR-10 design](fr-10/FR10-DESIGN-2026-09-23.md),
  [effects spec](../spec/fr10/README.md)).

## 7. Observation

Three read-only surfaces exist: `lane log` (the authoritative trail, read straight from the
store), the operator log (`operator.log.jsonl`, one line per command) and the daemon
console. Nothing reads any of them back to decide anything. `Foundry.Observations` is a
bounded query surface for the future status work (FR-18A). Next:
[observability](OBSERVABILITY.md).

## 8. Launch containment

Nothing in the tree launches an agent, promotes a candidate or activates a release. What
survives for later tickets is inert:

- `LaunchEligibility` with `Quota` is a pure launch policy with no callers. It allows
  subscription-only routes per role, has no paid fallback, and gives a stable refusal for
  any malformed policy. A model name or an available credential is never entitlement.
- `effects/process_group.ex` is a process leaf for FR-10.

Automatic launch returns only through FR-09 (a harness contract), FR-10 (owned effects) and
FR-15a (isolation). See the [dependency inventory](REPAIR-PLAN.md#dependency-inventory).

## 9. How the codebase keeps these guarantees

- **Boundary rules.** The decoupling rules. For example, Core never references Workflow,
  and role names appear in Core only at declared sites. Most are enforced by
  `test/foundry/architecture_boundary_test.exs`. See [boundary rules](BOUNDARY-RULES.md).
- **Evidence tools.** Generative checks test the guarded reducer against the written
  contract: row coverage, guard mutation and refusal sites. See
  [evidence tools](EVIDENCE-TOOLS.md) and the [coverage-guided sweep](COVERAGE-GUIDED-SWEEP.md).
- **Formal models.** Quint specs of the ledger, the Core boundary and FR-10 effects. See
  [spec/ledger](../spec/ledger/README.md), [spec/core_boundary](../spec/core_boundary/README.md)
  and [spec/fr10](../spec/fr10/README.md).
- **The gate.** `ci/run.exs` runs from fresh roots. It compiles with warnings as errors,
  checks formatting, runs the model-free suite and emits a provenance manifest. See
  [CI](CI.md).
- **Independent review.** Every change goes through the lane, and a fresh agent on a
  different model reviews it. See [agent brief](AGENT-BRIEF.md) and
  [dogfood log](batch-d/DOGFOOD-LOG.md).

## Glossary

| Term | Meaning |
|---|---|
| **Operator** | Whoever drives the lane: a human, or an LLM session acting for one. Operator-level decisions go to the human. |
| **Ticket** | One admitted unit of work: id (`ML-…`), base revision, file scope, acceptance criteria. |
| **Attempt** | One developer try at a ticket. A `correction` verdict starts a new attempt. |
| **Work packet** | The JSON brief `lane packet` writes for one agent: ticket, role, principal, base, scope, criteria. |
| **Effect** | A claimed external action, such as "a developer run for principal P". Issuing one spends allocation. It is closed by submit, review or settle. |
| **Principal** | The recorded identity an effect is issued to, e.g. `agent:<model>/<role>-<ticket>` or `human:<name>`. |
| **Candidate** | The commit a developer submits: the clean checkout's `HEAD`, descended from the base. |
| **Receipt** | Core's record binding an effect to its outcome (candidate, verdict, settlement). A rerun must match it. |
| **Allocation / ledger** | The budget of developer and reviewer starts, held in protected tables. |
| **Core** | `lib/foundry/durable_store/`: the store, its gateway and its protected primitives. |
| **Kernel** | `lib/foundry/workflow/`: the pure reducer that decides transitions. |
| **Controller** | Whatever decides what to do next. Today that is the operator. Later it may be a bundled Standard Controller or an external orchestrator. It proposes and never commits. |
| **Refusal** | A stable atom explaining why a command did not apply. |
| **Settle** | Closing an issued effect that produced no submission (`non_started` or `unknown`). |
| **Gate** | `ci/run.exs`, the full model-free check. It also means the architecture test that enforces the boundary rules. |
| **FR-NN** | A ticket in the [repair plan](REPAIR-PLAN.md), for example FR-09. **F**NN (no R) is an audit finding. |
| **ML-…** | A ticket run through the manual lane ([dogfood log](batch-d/DOGFOOD-LOG.md)). |
| **Batch** | A group of lane tickets integrated together on `integ/<batch>`, such as C1b or C2. |
| **Amendment (C1, Q10…)** | An operator-approved change recorded in the repair plan (C) or the dogfood log's decision table (Q). |
| **OMP, Herdr, Pi, Jido** | Agent harness and presentation tools. OMP and Herdr drove the deleted daemon. Pi and Jido.Harness are candidates for FR-09. |
| **Pramāṇa** | The project Foundry was split from on 2026-09-23. Commit SHAs in records dated before the split name Pramāṇa commits. Nothing in Foundry depends on it. |
