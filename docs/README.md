# Foundry documentation

[Foundry](../README.md) › Docs

Foundry is a governance kernel for AI agents that write code. It runs today as the
**manual lane**: an operator admits a ticket, hands each work packet to an agent and
records submit, review and settle through Core's durable store. It launches nothing.

## How to read these docs

The docs form a tree. Read from the top and stop as soon as you have what the task
needs. **LLM agents: do not preload.** Read the layer above, then open only the one
document your task names.

| Layer | What it is | Load when |
|---|---|---|
| 0 | [README](../README.md): what Foundry is and is not, where it is headed | always, once |
| 1 | [How Foundry works](CONCEPTS.md): every mechanism in plain terms, plus the glossary. This index. | you need the mechanism or a word defined |
| 2 | **Live reference**: describes the code on `main`, kept current | your task touches that area |
| 3 | **Authority**: the backlog and the contract, binding on every change | you pick, change or accept a ticket |
| 4 | **Direction and design ahead**: strategy and designs for code that does not exist yet | you make a design or investment choice |
| 5 | **Dated records**: reviews and designs kept because code or tests cite them | you need the history behind a specific decision |

Every document opens with a breadcrumb back to this page. A dated or design document
says its status in its first lines: read that before trusting its body. When a document
and the code disagree, the code is the fact, and the document needs a fix.

## Start by the task

| Task | Read |
|---|---|
| Understand what Foundry is | [README](../README.md), then [How Foundry works](CONCEPTS.md) |
| Run a ticket through the lane | [Lane runbook](batch-d/LANE-RUNBOOK.md) |
| Resume the current campaign | [Dogfood log handoff](batch-d/DOGFOOD-LOG.md#handoff-where-the-campaign-stands), then the runbook, then the [agent brief](AGENT-BRIEF.md) |
| Pick the next ticket | [Repair plan](REPAIR-PLAN.md#dependency-inventory): the sole backlog. It owns ordering, not any older sequence |
| Change any code | [AGENTS.md](../AGENTS.md), then the [boundary rules](BOUNDARY-RULES.md) |
| Write Elixir code or tests | [Elixir conventions](ELIXIR-CONVENTIONS.md) and the vendored [Phoenix rules](conventions/phoenix/elixir.md) |
| Add or change a guard, transition or refusal test | [Evidence tools](EVIDENCE-TOOLS.md), then the [coverage-guided sweep](COVERAGE-GUIDED-SWEEP.md) |
| Delegate work to an agent | [Agent brief](AGENT-BRIEF.md) |
| Build or run the gate | [CI](CI.md) and `ci/run.exs` |
| Understand the durable store | [Durable store](DURABLE-STORE.md), then the generated [schema reference](DURABLE-STORE-SCHEMA.md) |
| Observe a running lane | [Observability](OBSERVABILITY.md) |
| Understand execution authority | [Workflow contract](WORKFLOW-CONTRACT.md) |
| Check a protocol against its formal model | [Ledger](../spec/ledger/README.md), [Core boundary](../spec/core_boundary/README.md), [FR-10 effects](../spec/fr10/README.md) |
| Make a direction or investment choice | [Strategy working summary](STRATEGY.md#working-summary). It is context, not permission to bypass the plan or the contract |
| Rebuild a capability the deleted daemon had | [Moved knowledge](design/MOVED-KNOWLEDGE-2026-09-23.md) |

## Every document, by layer

### Layer 2: live reference

| Document | What it covers |
|---|---|
| [How Foundry works](CONCEPTS.md) | transport, lane, kernel, Core, principals, refusals, recovery, containment; glossary |
| [Lane runbook](batch-d/LANE-RUNBOOK.md) | start and stop the daemon, every `lane` command, refusals, recovery, logs |
| [Dogfood log](batch-d/DOGFOOD-LOG.md) | the operator's record: handoff, ticket table, decisions (Q), frictions (F), scorecard |
| [Agent brief](AGENT-BRIEF.md) | standing clauses every delegated task inherits |
| [Boundary rules](BOUNDARY-RULES.md) | the decoupling rules and the test that enforces each one |
| [Durable store](DURABLE-STORE.md) | the SQLite authority store: gateway, initialization, recovery, versions |
| [Schema reference](DURABLE-STORE-SCHEMA.md) | generated from `database.ex`; a test fails if they drift. Do not edit |
| [Observability](OBSERVABILITY.md) | the three read-only surfaces, and what was deleted |
| [CI](CI.md) | the standalone gate and its provenance manifest |
| [Evidence tools](EVIDENCE-TOOLS.md) | generative checks of a guarded reducer against its written contract |
| [Coverage-guided sweep](COVERAGE-GUIDED-SWEEP.md) | the guard mutation sweep and its gate design |
| [Elixir conventions](ELIXIR-CONVENTIONS.md), [Phoenix rules](conventions/phoenix/elixir.md) | coding rules (the Phoenix file is vendored verbatim) |
| [Ledger spec](../spec/ledger/README.md), [Core boundary spec](../spec/core_boundary/README.md), [FR-10 effects spec](../spec/fr10/README.md) | Quint models and what each proves |

### Layer 3: authority

| Document | What it owns |
|---|---|
| [Repair plan](REPAIR-PLAN.md) | the sole backlog: every FR ticket, status, dependencies, acceptance, amendments |
| [Workflow contract](WORKFLOW-CONTRACT.md) | FR-06: identities, transitions, budgets, isolation, integration, activation. Tests parse its tables |

A review's approval applies to its named candidate only. It does not endorse later
revisions or show that a protected route is active.

### Layer 4: direction and design ahead

None of these change the plan, the contract or runtime behaviour. Each says so in its
first lines.

| Document | What it covers |
|---|---|
| [Strategy brief](STRATEGY.md) | investment direction: models direct and the kernel governs; compose before build |
| [Product strategy](strategy/PRODUCT.md) | mission, post-repair initiatives I-F1 to I-F5, open decisions |
| [Validation](strategy/VALIDATION.md), [Research register](strategy/RESEARCH.md) | how success is measured; external sources checked |
| [Orchestrator boundary](design/ORCHESTRATOR-BOUNDARY.md) | replaceable controllers over one authority plane |
| [Ecosystem boundary](design/ECOSYSTEM-BOUNDARY.md) | what Foundry owns and what it reuses |
| [Workflow profiles](design/PROJECT-WORKFLOW-PROFILES.md), [Planning strategies](design/PLANNING-STRATEGIES.md) | project-declared workflows; model-proposed plans |
| [Pi harness](design/PI-HARNESS.md), [Jido harness](design/JIDO-HARNESS.md) | FR-09 harness candidates |
| [AX substrate](design/AX-SUBSTRATE.md), [Cloudflare OS](design/CLOUDFLARE-OS.md) | execution backend and resource-broker candidates |
| [FR-10 design](fr-10/FR10-DESIGN-2026-09-23.md) | owned effects and reconciliation |
| [Decompose gateway](design/DECOMPOSE-GATEWAY.md), [Decompose protected primitives](design/DECOMPOSE-PROTECTED-PRIMITIVES.md) | approved batch C2 splits of two Core modules |
| [O0 authority inventory](orchestrator/O0-AUTHORITY-INVENTORY-2026-09-22.md), [O1 sequencing](orchestrator/O1-SEQUENCING-PROPOSAL-2026-09-23.md) | the orchestrator seam, step by step |

### Layer 5: dated records kept in the tree

These are true at the commit they name, not necessarily now. They stay because code,
tests or live docs cite them.

| Document | Why it is here |
|---|---|
| [Bounded effect query](design/bounded-effect-query-design.md) | the FR-18A read interface's design, now implemented; cited by observability |
| [Dogfood readiness](DOGFOOD-READINESS-2026-09-23.md) | the thin-dogfood decision and the lane's accepted risks |
| [Thin lane design](batch-d/THIN-LANE-DESIGN-2026-09-23.md), [its review](batch-d/thin-lane-review-findings-2026-09-23.md) | the lane's design; tests cite it |
| [Moved knowledge](design/MOVED-KNOWLEDGE-2026-09-23.md) | edge cases of the deleted daemon and which of FR-09 to FR-13 owns each |
| [FR-08 files](fr-08/README.md) | kernel and Core designs, specs and fixtures that tests read |
| [Clean-room sweep](fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md), [FR-23 split](fr-23/FR-23-SPLIT-PROPOSAL-2026-09-22.md), [worktree inventory](fr-23/WORKTREE-INVENTORY-2026-09-23.md) | the FR-23 clean-up audit and plan |
| `batch-d/reviews/` | one review per lane ticket, linked from the [dogfood log ticket table](batch-d/DOGFOOD-LOG.md#tickets) |

Everything else that is dated (audits, candidates, attestations, retired mechanisms, the
implementation log, the pre-split [meta-harness proposal](https://github.com/lorecrafting/foundry/blob/records/2026-09-24/docs/strategy/META-HARNESS.md)) is at tag `records/2026-09-24`
([docs/archive at the tag](https://github.com/lorecrafting/foundry/tree/records/2026-09-24/docs/archive)).

## Keeping this tree healthy

- A new document gets a breadcrumb line under its title, a status line if it is dated or
  design-ahead, and a row in the layer table above.
- `elixir bin/check_docs.exs` fails on any relative link that does not resolve, or any
  `#anchor` that names no heading in its target.
- [AGENTS.md](../AGENTS.md) applies to every provider. That neutrality does not relax
  launch policy, billing authorization, review identity or backend conformance.
