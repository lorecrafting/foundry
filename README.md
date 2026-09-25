# Foundry

**Foundry is a governance kernel for AI agents that write code.** It keeps a durable,
tamper-evident record of what an agent was asked to do and what it was allowed to spend.
It also records what the agent actually delivered, and whether an independent reviewer
accepted it. Agents do the work. Foundry decides what counts.

> **Status (2026-09-25): early and not in production.** Foundry runs today as the
> [manual lane](docs/batch-d/LANE-RUNBOOK.md). It records work but launches nothing:
> a human or LLM operator hands each work packet to an agent by hand. Foundry is being
> built by using it on itself ([dogfood log](docs/batch-d/DOGFOOD-LOG.md)).

## The problem

Coding agents are now capable enough to do real work unattended. The hard part has moved
from getting an agent to act to trusting what it did:

- An agent reports "tests pass". Did they pass, on which commit?
- Did the reviewer see the same code the developer submitted, and were they
  independent, or the same model checking its own work?
- A session crashed halfway through. What finished, what is still uncertain, and what is
  safe to retry?
- Did the run stay within its budget, or quietly fall back to a paid API?

Most agent tooling improves the agent: better prompts, more tools, bigger task graphs.
Foundry works on the other side of that line. It is the part that does not trust the
agent.

## The value proposition

Foundry lets capable models direct useful work while it keeps these guarantees:

| Guarantee | What it means in practice |
|---|---|
| **Admitted intent** | Work starts as an admitted ticket with a base commit, a file scope and acceptance criteria. Agents cannot widen it. |
| **Bounded authority and budget** | Every agent run spends a pre-granted allocation. There are no paid fallbacks, and no eligible budget means the work waits with a reason. |
| **Exact evidence** | A submission is a specific commit in a clean checkout, descended from the admitted base. Reviews bind to that exact commit. |
| **Independent acceptance** | Core refuses a reviewer whose recorded principal did the developer work. An agent's own claim never counts as acceptance. Until isolation lands (FR-15aB), principals are recorded, not authenticated. |
| **Durable, replayable state** | Every acknowledged decision is a committed event in one SQLite store. A restart replays it, and uncertain outcomes are reconciled before any retry. |
| **Observation is not authority** | Logs, process exits and transcripts can explain work. They cannot admit, accept or integrate anything. |

The short version is a phrase from the [strategy](docs/STRATEGY.md#working-summary):
*a working process is not progress; progress is not completion; completion is not
acceptance.*

## How it works, in one pass

```text
 operator            Foundry (manual lane)                     agents
 ────────            ─────────────────────                     ──────
 lane admit   ──►  ticket: base, scope, acceptance
 lane packet  ──►  developer packet (spends one allocation) ──►  developer works in its own worktree
                                                             ◄──  lane submit <commit> <checkout>
 lane packet  ──►  reviewer packet (different principal)   ──►  fresh reviewer, different model
                                                             ◄──  lane review: approved | correction | rejected
                   ready_to_integrate
 git (manual) ──►  lane integrated: is base..candidate in main?
```

Each arrow into Foundry is a command. The kernel checks it against the current state and
refuses it with a stable reason if it does not fit, for example `wrong_source_phase` or
`candidate_mismatch`. Otherwise it is committed as an event. [How Foundry works](docs/CONCEPTS.md)
explains each mechanism (the store, the kernel, packets, principals, reviewer independence,
refusals, recovery) and defines the vocabulary.

## What Foundry is not

- **Not a coding agent or harness.** It does not write code or prompt models. Claude,
  Codex, Pi or any other agent does the work. Foundry records and governs it.
- **Not an orchestrator or DAG engine.** Planning, decomposition and sequencing belong to
  replaceable controllers, which can be model-driven. Foundry owns the rules that judge
  their results, and keeps them where the planner cannot change them
  ([orchestrator boundary](docs/design/ORCHESTRATOR-BOUNDARY.md)).
- **Not a sandbox, yet.** Nothing in the tree launches an agent, so nothing needs
  sandboxing today. Isolated execution is a prerequisite for automatic launch (FR-15a), not
  something Foundry has now.
- **Not a model gateway or billing system.** It never grants entitlement. A model name or an
  available credential is not permission to spend.
- **Not production software.** It is not limited to one operator or machine, but so far it
  has only run that way, on its own repository. There is no release, no multi-tenant
  story, and no stability promise on any interface.

## Where it is headed

The [repair plan](docs/REPAIR-PLAN.md) is the sole backlog. It restores capabilities in
order, each behind evidence:

1. **Now: the manual lane, and cleaning up the codebase.** Batch C2 adds precision tooling
   for agents and splits two oversized Core modules. The live queue is the
   [dogfood log handoff](docs/batch-d/DOGFOOD-LOG.md#handoff-where-the-campaign-stands).
2. **Next: governed execution.** Foundry launches agents itself, inside a proven isolation
   boundary, through one small harness contract (FR-09, FR-10, FR-15a). Pinned Pi RPC is the
   preferred first harness to evaluate
   ([Pi harness](docs/design/PI-HARNESS.md)).
3. **Then: the full lifecycle.** Corrections, timeouts, scheduling, verified check receipts,
   Git integration and activation of accepted builds (FR-11 to FR-17), proved end to end
   by FR-22.
4. **Longer term: a portable kernel.** One stable authority plane with replaceable
   controllers, harnesses and execution backends. It becomes a place to compare workflow
   strategies and models by accepted outcomes, not token counts
   ([product strategy](docs/strategy/PRODUCT.md)).

Automatic launch stays closed until its owning tickets pass. The only surviving launch
policy, `LaunchEligibility`, has no callers. It allows subscription-only routes and refuses
any malformed policy.

## Quick start

You need the Elixir/Erlang toolchain pinned in `mise.toml`, plus `git` and `python3`.

```sh
mix deps.get
TMPDIR=/private/tmp MIX_ENV=test mix test        # model-free suite
bin/foundry-lane build && bin/foundry-lane start  # the lane daemon
bin/foundry lane status
```

To run a real ticket through the lane, follow the [lane runbook](docs/batch-d/LANE-RUNBOOK.md).
The full gate is `TMPDIR=/private/tmp elixir ci/run.exs --output <dir outside the repo>`
([CI](docs/CI.md)).

## Read next

| If you want to… | Read |
|---|---|
| Understand the mechanisms and vocabulary | [How Foundry works](docs/CONCEPTS.md) |
| Find any document, by task or by layer | [Documentation index](docs/README.md) |
| Run the lane | [Lane runbook](docs/batch-d/LANE-RUNBOOK.md) |
| See what is next | [Repair plan](docs/REPAIR-PLAN.md), then the [dogfood log handoff](docs/batch-d/DOGFOOD-LOG.md#handoff-where-the-campaign-stands) |
| Change code | [AGENTS.md](AGENTS.md), then the [boundary rules](docs/BOUNDARY-RULES.md) |
| Understand why | [Strategy working summary](docs/STRATEGY.md#working-summary) |

## Repository layout

```text
lib/foundry/
  manual_lane/     the lane: CLI, backend, server, log, replay
  workflow/        the pure workflow kernel: decides transitions, never writes
  durable_store/   Core: the SQLite authority store and its gateway
  observations/    bounded read queries over the store
  repair/          FR-08A attestation modules
  cli/rpc.ex       inert command transport; dispatches lane commands only
  launch_eligibility.ex, quota/, effects/   policy and process leaves kept for FR-09/FR-10
test/              model-free ExUnit suite, including the architecture gate
bin/               foundry (RPC wrapper), foundry-lane, evidence tools, doc checker
ci/run.exs         the gate
spec/              Quint models of the ledger, the Core boundary and FR-10 effects
docs/              everything above; start at docs/README.md
```

Git holds source, tests, specs and the lockfile. It does not hold live state, logs,
releases or provider credentials. The operator runtime root defaults to the ignored
`local/` directory in the main checkout (`FOUNDRY_OPERATOR_RUNTIME_ROOT` overrides it).
It must never come from a task worktree.

## History

Foundry was split from the Pramāṇa project on 2026-09-23, with its full history. It is
now fully independent: it depends on no Pramāṇa code, service, document or process. Commit SHAs recorded
before the split name Pramāṇa commits. The legacy daemon stack was deleted rather than
migrated ([plan amendment C1](docs/REPAIR-PLAN.md#clean-room-amendment)). The edge cases its
tests encoded are kept in [moved knowledge](docs/design/MOVED-KNOWLEDGE-2026-09-23.md).
Audits and other dated records are at tag
[`records/2026-09-24`](https://github.com/lorecrafting/foundry/tree/records/2026-09-24/docs/archive).
