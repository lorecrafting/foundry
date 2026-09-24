# Observability

Observation is never authority ([boundary rule 9](BOUNDARY-RULES.md)). A log line, a
process exit or an agent's "tests pass" can explain work; it cannot admit, accept or
integrate anything. Authority lives in the durable store's committed events, written only
through Core's protected transactions ([durable store](DURABLE-STORE.md)).

## What exists today

Foundry runs as the manual lane ([runbook](batch-d/LANE-RUNBOOK.md#6-logs)). It has three
observation surfaces, and nothing reads any of them back to decide anything:

| Surface | Where | What it holds |
|---|---|---|
| `lane log [ID]` | reads the lane store read-only (`ManualLane.Log.trail/2`) | per ticket: committed events in commit order, the commands Core refused under that ticket's command ids, and each effect's observation page |
| Operator log | `operator.log.jsonl` beside the lane store (`ManualLane.Log.operator/2`) | one JSON line per lane command: `ts`, `argv`, `principal`, `result`, `ticket_id`, `phase`, `duration_ms`. A failed write warns on stderr and never changes the command's outcome |
| Daemon console | the release's `tmp/log/erlang.log.*` | `Logger` start and finish lines per lane command, and recovery entry and exit |

`lane log` also runs while the Gateway is in recovery, because it opens SQLite read-only.
`Foundry.Observations` is a bounded, read-only query surface over the same protected
facts; tests exercise it, and no lane command calls it yet.

## What is gone

The legacy telemetry described here before 2026-09-23 (the four JSONL logs under
`local/state/current/`, `ConsolidatedLog`, the telemetry schemas and export, system metrics,
the health probe, the Improver and their CLI commands) was deleted with the daemon stack in
batch A1 ([clean-room amendment](REPAIR-PLAN.md#clean-room-amendment)). That document, with
its OpenTelemetry direction, correlation model and target execution-observation contract,
is [archived](https://github.com/lorecrafting/foundry/blob/records/2026-09-24/docs/archive/OBSERVABILITY.md): read it as design input for FR-18, not as a
description of the code.
