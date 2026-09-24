# Foundry documentation

Foundry is an OTP execution and governance system for supervised agent work. Today it runs
as the **manual lane**: an operator admits a ticket, hands each work packet to an agent and
records submit, review and settle through Core's durable store. It launches nothing.
[The overview](../README.md) says what exists; the [repair plan](REPAIR-PLAN.md) says what
comes next.

## Start by the task

| Task | Read |
|---|---|
| Run a ticket through the lane | [Lane runbook](batch-d/LANE-RUNBOOK.md); its design and accepted risks are in [THIN-LANE-DESIGN](batch-d/THIN-LANE-DESIGN-2026-09-23.md) |
| See what dogfooding the lane has found | [Dogfood log](batch-d/DOGFOOD-LOG.md) |
| Resume repairs or pick the next ticket | [Repair plan](REPAIR-PLAN.md): the sole backlog, with status, dependencies and acceptance. It, not any older sequence, owns ordering |
| Understand execution authority | [Workflow contract](WORKFLOW-CONTRACT.md) |
| Change any code | [Boundary rules](BOUNDARY-RULES.md) first: twelve decoupling rules, each naming its enforcing test or review |
| Add or change a guard, transition or refusal test | [Evidence tools](EVIDENCE-TOOLS.md); the guard mutation sweep and its gate design are in [coverage-guided sweep](COVERAGE-GUIDED-SWEEP.md) |
| Write Elixir code or tests | [Elixir conventions](ELIXIR-CONVENTIONS.md) and the synced [Phoenix rules](conventions/phoenix/elixir.md) |
| Delegate work to an agent | [Agent brief](AGENT-BRIEF.md); repository-wide rules are in [AGENTS.md](../AGENTS.md) |
| Build or run the gate | [CI](CI.md) and `ci/run.exs` |
| Understand the durable store | [Durable store](DURABLE-STORE.md), then the generated [schema reference](DURABLE-STORE-SCHEMA.md) (a test fails if it drifts from `database.ex`) |
| Observe a running lane | [Observability](OBSERVABILITY.md): `lane log`, the operator log, the daemon console |
| Check a protocol against its formal model | Quint specs: [R5 ledger](../spec/ledger/README.md), [Core boundary](../spec/core_boundary/README.md), [FR-10 effects](../spec/fr10/README.md) |
| Direction, product and investment choices | [Strategy working summary](STRATEGY.md#working-summary), then [strategy/](strategy/PRODUCT.md) (product, validation, research, meta-harness). Context, not permission to bypass the plan or contract |
| Design ahead of the code | [design/](design/ECOSYSTEM-BOUNDARY.md): ecosystem and [orchestrator](design/ORCHESTRATOR-BOUNDARY.md) boundaries, [workflow profiles](design/PROJECT-WORKFLOW-PROFILES.md), [planning strategies](design/PLANNING-STRATEGIES.md), [Pi](design/PI-HARNESS.md) and [Jido](design/JIDO-HARNESS.md) harnesses, [AX](design/AX-SUBSTRATE.md) and [Cloudflare](design/CLOUDFLARE-OS.md) substrates, [bounded effect query](design/bounded-effect-query-design.md); plus [FR-10](fr-10/FR10-DESIGN-2026-09-23.md) and orchestrator steps [O0](orchestrator/O0-AUTHORITY-INVENTORY-2026-09-22.md) and [O1](orchestrator/O1-SEQUENCING-PROPOSAL-2026-09-23.md) |
| Rebuild a capability the deleted daemon had | [Moved knowledge](design/MOVED-KNOWLEDGE-2026-09-23.md): each edge case the deleted tests encoded and which of FR-09–FR-13 owns it |
| Current clean-up plan | [Clean-room sweep](fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md) |
| FR-08 design and review record (awaiting per-file triage) | [`fr-08/`](fr-08/investigation.md); some files there are read by tests |
| Anything dated: audits, candidates, reviews, attestations, retired mechanisms, the implementation log | [Archive](archive/README.md) |

A review's approval applies to its named candidate only; it does not endorse later revisions
or show that a protected route is active.

## Provider and backend boundary

[AGENTS.md](../AGENTS.md) applies to every provider. That neutrality does not relax launch
policy, billing authorization, review identity or backend conformance. Any future harness
adapter passes FR-09 before it runs anything.
