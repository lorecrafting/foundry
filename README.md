# Foundry

Split from [lorecrafting/pramana](https://github.com/lorecrafting/pramana) on 2026-09-23 with
its full history. Commit SHAs recorded before the split name Pramāṇa commits; the two that
tests resolve survive here as `pramana/<sha>` tags.

**Current shape, 2026-09-23:** Foundry is not in production. The legacy daemon stack
(Coordinator, AgentServer, the Herdr adapter, launch effects, JSONL persistence, Board,
telemetry, Improver, PM, Scheduler and the legacy CLI) was deleted rather than migrated
([plan amendment C1](docs/REPAIR-PLAN.md#clean-room-amendment)). The
[manual lane](docs/batch-d/LANE-RUNBOOK.md) over the durable store and the workflow kernel is
the only ingress, and it launches nothing: the operator hands each work packet to an agent.
Edge cases the deleted tests encoded are listed, with their owners, in
[moved knowledge](docs/design/MOVED-KNOWLEDGE-2026-09-23.md).

The project remains independent of the Phoenix umbrella, Postgres, the research corpus, and
`priv/embed/`.

## Independent CI and build provenance

The [Foundry-only CI job](docs/CI.md) runs from this directory with fresh dependency, build,
temporary and runtime roots. It compiles with warnings as errors, enforces all new formatting,
runs the model-free suite and emits source/tool/dependency/escript provenance. It starts no
corpus service, live daemon or provider session. Real-provider and activation evidence remain
explicit downstream acceptance, not implied by a green CI job.

## Acceptance and launch containment

Nothing in the tree promotes a candidate, activates a release or launches an agent. The lane
records a candidate only when it is the checkout's HEAD with the admitted base as an
ancestor, binds each receipt to its claimed effect, and Core refuses a reviewer who is not
independent of the developer. FR-13 restores controller-verified artifact and check evidence,
FR-14 protected Git promotion, and FR-17 immutable accepted-build activation.

The FR-01 launch policy survives as a pure leaf, `LaunchEligibility` with `Quota`, called by
nothing: subscription-only eligibility per role, no paid fallback, and a stable refusal for
any malformed policy. FR-09 decides what harness calls it; do not treat a model name,
available credential or this policy as entitlement.

The [Foundry strategy](docs/STRATEGY.md#pi-explicit-session-contracts-and-replaceable-execution)
prefers a bounded pinned-Pi-RPC evaluation for that harness. No production harness, FR-06
authority contract or automatic-launch permission changes until a candidate passes FR-09/15a
and any affected contract text is explicitly revised and re-reviewed.

## Command transport

`bin/foundry` treats every user argument as inert data. It invokes Elixir with those values
only in `System.argv/0`, encodes a bounded versioned JSON envelope as canonical URL-safe
base64, and sends one fixed `Foundry.CLI.RPC.run/1` expression to the release.
The daemon rejects malformed, duplicate-key, oversized, non-UTF-8 and NUL-containing
payloads, and every command that is not a `lane` command its parser accepts. The wrapper
preserves remote stdout, stderr and exit status.

This is FR-02 containment, not a claim that the release's general `rpc` evaluator is a
safe public authority boundary. Keep access local/protected; FR-15a replaces that general
evaluation credential.

## Read first

- [`docs/README.md`](docs/README.md) — the documentation index, by task.
- [`docs/batch-d/LANE-RUNBOOK.md`](docs/batch-d/LANE-RUNBOOK.md) — start the lane daemon and
  run a ticket through it.
- [`docs/REPAIR-PLAN.md`](docs/REPAIR-PLAN.md) — sole authoritative repair backlog,
  current status, dependencies and acceptance obligations.
- [`docs/WORKFLOW-CONTRACT.md`](docs/WORKFLOW-CONTRACT.md) — accepted FR-06 authority,
  lifecycle and budget contract.
- [`docs/BOUNDARY-RULES.md`](docs/BOUNDARY-RULES.md) — the decoupling rules every code change
  keeps.
- [`docs/DURABLE-STORE.md`](docs/DURABLE-STORE.md) — the SQLite authority store,
  initialization and recovery.

Why the repairs exist (the [2026-09-12 audit](https://github.com/lorecrafting/foundry/blob/records/2026-09-24/docs/archive/AUDIT-2026-09-12.md) and later
audits) and every other dated record are archived (tag `records/2026-09-24`, [docs/archive at the tag](https://github.com/lorecrafting/foundry/tree/records/2026-09-24/docs/archive)).

## Tracked layout

```text
./
  mix.exs, mix.lock, .formatter.exs
  config/config.exs           — operator runtime root only
  lib/foundry/
    application.ex            — starts ManualLane.Server when FOUNDRY_MANUAL_LANE=1, else nothing
    manual_lane/              — the lane: CLI, backend, server, log, replay
    workflow/                 — the pure workflow kernel (Workflow.Kernel*)
    durable_store/            — Core: the SQLite authority store and its gateway
    observations/             — bounded read queries over the store
    repair/                   — FR-08A/FR-08 attestation modules
    cli/rpc.ex                — FR-02 inert transport; dispatches lane commands only
    work_packet.ex, git_evidence.ex, runtime_root.ex, schema_reference.ex, ci.ex
    launch_eligibility.ex, quota/, effects/process_group.ex — policy and process leaves kept for FR-09/FR-10
  test/
  bin/                         — pramana (RPC wrapper), foundry-lane, evidence tools
  ci/run.exs                   — the gate
  spec/                        — Quint models
  docs/
  README.md
```

Source, tests, specs, sanitized milestone records and the dependency lockfile belong in Git.
Hex dependency sources and generated executables are restored from the lockfile/source and
identified by the CI provenance manifest; they do not belong in Git. Live state,
transcripts, caches, logs, releases, temporary files, worktrees and provider authentication
do not.

The operator runtime root defaults to `local/` in the main checkout (`config/config.exs`;
`FOUNDRY_OPERATOR_RUNTIME_ROOT` overrides it). It is ignored by Git and is fixed when the
release is built from the main checkout; it must never be derived from a task worktree.
Provider credentials stay in provider-owned locations outside that root.

## Running

`bin/foundry-lane build|start|stop|status` builds and drives the lane daemon's release; the
[runbook](docs/batch-d/LANE-RUNBOOK.md) covers its settings, every `bin/foundry lane …`
command and recovery. A node started without `FOUNDRY_MANUAL_LANE=1` starts no children.
