# Knowledge moved out of the deleted daemon stack — 2026-09-23

[Foundry](../../README.md) › [Docs](../README.md) › Knowledge moved out of the deleted daemon stack — 2026-09-23

**Why this exists.** Plan amendment [C1](../REPAIR-PLAN.md#clean-room-amendment) deleted the
legacy daemon stack instead of migrating it (ticket ML-DEL-DAEMON, following the
[clean-room sweep](../fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md) §1.1 and §2). The deleted tests
encoded edge cases that the forward path (the manual lane over Core) still has to respect when
FR-09 to FR-13 rebuild the matching capability on Core. This note lists each one, the test
that encoded it, and where it lives now or which ticket owns it.

**Reading a deleted test.** Every path below existed at `db4334c`:
`git show db4334c:test/foundry/<file>`. "Covered" means a surviving test states the
same property for the forward path; "owner" means nothing states it yet.

## The five items the sweep named (§2 "Knowledge that moves")

| Knowledge | Deleted test that encoded it | Now |
|---|---|---|
| Telemetry never carries a body or secret: records with any of `prompt prompt_body response response_body transcript environment env credentials secrets provider_payload corpus_text` are refused, and command argv values after `--token` or in `api_key=` form are replaced by `[REDACTED]` | `telemetry/telemetry_test.exs` "LLM metrics preserve unavailable values and reject sensitive bodies", "command telemetry redacts secrets and never invents token fields"; field list at `lib/foundry/telemetry/telemetry.ex:216`. Also: a launched command's environment is recorded with values redacted but the declared keys kept (`checks/runner_test.exs` "sanitize_env redacts values while preserving which keys were declared") | **Owner: ML-KNOWLEDGE-NOTES.** `ManualLane.Log` (`manual_lane/log.ex`, `operator.log.jsonl`) writes argv unredacted today; the redaction and its test belong there |
| FR-01 launch policy: subscription-only eligibility for each role; paid, manual, premium, exhausted, unknown-quota, role-disallowed and cooling-down profiles all refused; no paid fallback; every malformed nested policy gives a stable blocked reason | `autonomous_launch_test.exs:86-148` | **Covered, kept as a leaf:** moved verbatim to `test/foundry/launch_eligibility_test.exs`. The rest of that file (`:195-873`) drove Tick and AgentServer; see "Launch" below. FR-09 decides what calls `LaunchEligibility` next |
| Process identity drift: a live process may change `command` without becoming another process, so "still running" compares pid, group and start time, never argv | `checks/status_test.exs` "a process that exec'd is still :running -- command may change, incarnation may not", "a different incarnation on the same pid is still :uncertain" | **Covered in part:** `Effects.ProcessGroup` and `effects/process_group_test.exs` are kept. The `signal/4` refusal of a stale identity ("a stale identity (already exited) is refused rather than signalled", "a replacement-owner mismatch … refuses to signal a live process" in the deleted `checks/runner_test.exs`) is re-covered by two `process_group_test` cases that send no signal. **Gap, owner FR-10:** real termination and descendant cleanup ("cancellation terminates the check well before its natural exit"), and the setsid-per-launch rule that makes `kill -<pgid>` correct ("the published child PID is bound to its launch token and owns a separate process group"), were exercised only there |
| A clean release waits for the effect subtree to quiesce before the owner lock is released | `runtime_startup_boundary_test.exs` "clean release waits for the effect subtree to quiesce" (and "bridge loss quiesces the runtime and refuses automatic takeover") | **Owner: FR-10** worker monitoring ([FR10-DESIGN](../fr-10/FR10-DESIGN-2026-09-23.md)). The store-level half — two OS owners, a stale PID is not authority, fail-closed takeover evidence — is covered by `DurableStore.Owner` and the `durable_store/*` owner tests |
| Relocation rules (verify copy before removal, digest, live handles block, collision-safe rollback) | relocation tests | Not this ticket: ML-DEL-RELOCATION (C3) |

## Further knowledge found in the deleted tests

| Knowledge | Deleted test | Now |
|---|---|---|
| A launch is checkpointed intent → start → completion; a crash after intent never re-runs the start, an uncertain launch fails explicitly, and a re-launch after completion is a pure read | `effects/launch_test.exs` (all five tests) | **Owner: FR-10** (owned effects persisted before the external call; [effects model](../../spec/fr10/effects.qnt)) |
| Prompt delivery is at most once: a crash between intent and delivery looks for the text in the transcript instead of resending, and ambiguous evidence parks rather than guessing | `effects/prompt_delivery_test.exs` "a crash between intent and delivery never resends…", "ambiguous delivery with no transcript evidence parks rather than guessing either way" | **Owner: FR-09** (harness contract: prompt/observe) and FR-10 (reconcile) |
| Silence is not evidence: a spinner string or wall-clock quiet never counts; a check or tool with its own deadline is exempt; the watchdog fires strictly after the bound and only on durable evidence | `effects/silence_watchdog_test.exs` | **Owner: FR-11** (timeout lifecycle) |
| Deadline beats a late zero exit (a check finishing after its deadline is `:timeout`); no completion and no live match is `:uncertain`, never success; completion after a stop intent is diagnostics, not promotable | `checks/status_test.exs`, `checks/adoption_test.exs`, `checks/runner_test.exs` "deadline expiry outranks a late zero exit…" | **Owner: FR-13** (check receipts from the kernel's `check_*` events). The lane's check set is empty today (LANE-RUNBOOK §7) |
| Presentation identity: a recorded native session never silently downgrades to the terminal fallback; cleanup closes only after exact agent, session, pane and terminal re-inspection; a recycled or foreign occupant survives | `herdr/identity_test.exs`, `herdr/adapter_test.exs` | **Owner: FR-09**, designed against the selected harness rather than Herdr. Argv shape rules (no shell string; prompt text one argv element; native args only after `--`) from `herdr/argv_test.exs` go with it |
| Cleanup is a durable obligation: an owned resource needs a terminal receipt independently of the work verdict; only an exact matching receipt releases it; a pending cleanup holds capacity and blocks ordinary admission | `transition_test.exs`, `coordinator_test.exs` "unresolved launch failure and crash retain capacity without ordinary retry", `runtime_startup_boundary_test.exs` production-topology tests | **Owner: FR-10** (settlement) and **FR-12** (capacity) |
| Adoption is bounded by a pre-start baseline: when an agent start fails, a process that appears afterwards is never adopted as the started agent | `agent_server_test.exs` "agent-start failure never adopts a replacement process after the pre-start baseline" | **Owner: FR-10** (reconcile), the adoption side of the presentation-identity row above |
| Message order does not lose work: a queued tick and a handoff complete in either mailbox order without losing the handoff | `coordinator/engine_test.exs` "queued tick and handoff complete in either mailbox order without losing the handoff" | **Owner: FR-10**, for whatever process replaces the Coordinator's mailbox |
| Correction budget: two rejected reviews prepare corrections, the third parks the ticket; a review-validation failure spends a retry budget before parking | `assignments/assignments_test.exs` "third rejection exceeds limit (2) and parks ticket", `coordinator_test.exs` "review retry budget exhaustion parks the task" | **Owner: FR-11** (correction lifecycle). |
| Planning-attempt cap: same-reason rejections halt the planner, differing reasons reset the streak, a total ceiling halts, suspension neither extends nor breaks the count, and only a human `reset_pm_attempts` clears the halt | `pm/pm_test.exs` "planning attempt cap semantics", `pm/attempt_lifecycle_test.exs` | **Owner: FR-12**, with `Workflow.Kernel.Software.Planning` holding the forward PM events. PM proposals never act as admission (O0 C9) |
| Parallel admission: disjoint scopes and resources may run together; differing bases, colliding checkouts, missing run IDs, overlapping scopes, shared ports or any exclusive resource class conflict; an empty scope overlaps everything | `scheduler/scheduler_test.exs` | **Owner: FR-12.** The scheduler's resource keys (`corpus database gpu …`) were Pramāṇa-shaped and are not carried |
| No synthetic acceptance: `auto_approve` in any spelling is refused at every ingress; a stale candidate cannot stand in for checkout HEAD; review needs the independently issued reviewer identity | `fr05_containment_test.exs`, `cli_test.exs` validators | **Covered for the lane:** `git_evidence` refusal, `receipt_provenance_mismatch`, `principal_not_independent` (Core), `manual_lane/cli_test.exs`. **Gap:** `GitEvidence` has no direct test → ML-GITEVIDENCE-TEST, including its refusal of a checkout with uncommitted or untracked files (`git_evidence.ex:66-73`), formerly encoded by `coordinator/recovery_test.exs` "dirty task checkout is refused on handoff and prevents promotion" |
| Unavailable or corrupt is not empty and healthy: a torn or schema-invalid log enters visible recovery, preserves the bytes and admits no work | `legacy_persistence_containment_test.exs`, `stress_test.exs` | **Covered** for the SQLite store: `durable_store/sync_fault_test`, `operational_storage_test`, `quarantine_exit_probe_test`, `Observations` (FR-18A) |
| Forecasts keep censored, blocked and outlier outcomes visible and report "unavailable" instead of false precision | `telemetry/forecast_test.exs` | **Owner: FR-18B** projections, if forecasting returns |
| The Gateway accepted a legacy JSONL event as an idempotent `legacy_event_append` command | `durable_store/gateway_test.exs` "legacy EventLog writers can opt into the checked durable boundary" (removed with `EventLog` and `CompatibilityWriter`) | Idempotency conflicts stay covered by `gateway_test`, `atomic_bundle_test` and `protected_primitives_test`. The `legacy_event_append` command type left in pinned Core files is dead vocabulary → ML-DEAD-VOCAB |
| JSONL import: an unterminated tail, a malformed line (with its line number) and invalid UTF-8 are refused with the source path | `schema_test.exs` "contains malformed, non-UTF8, and oversized JSON and JSONL artifacts" (the `Import.read_jsonl` half) | `schema_test` keeps the JSON half. JSONL import itself goes with ML-DEL-LEGACY-IMPORT; fresh stores leave nothing to import |

## Deleted with nothing to carry

Board rendering and keyboard navigation, `SystemMetrics`, the runtime revision label,
Python-era projections, the tokenizer benchmark, `Preparation` and the retired `Parity` shim
(`board_test`, `board/inspection_test`, `system_metrics_test`, `status/*`, `projections/*`,
`preparation_test`, `policy_test`), and the split-layout scope checks of `HardeningPM` and
`Improver` (`hardening_pm_test`, `improver_test`, `improver_proposal_gate_test`; FR-20
re-derives constrained improvement on Core).

## Legacy import and H0 retired

Plan amendment C3/C4 (ticket ML-DEL-LEGACY-IMPORT) deleted `LegacyImport`, `LegacyLine`,
`Schema`, `AtomicFile`, `H0AcceptedFR07Boundary`, their tests and `test/fixtures/python`, and
dropped the `immutable_legacy_import` capability from `FR08HandoffGate` (six capabilities
now). Every deleted path exists at `5fb7603`. `DurableStore.Kernel` lost only its unused
`decide`/`apply` callbacks and `validate_bundle/1`; `normalize_bundle/1` stays because
`Gateway` calls it. `Authority` now lists `import_runs` and `legacy_records` as unsupported
retained authority: a row in either fences startup (`authority_test` "every unsupported
authority table fences startup").

| Knowledge | Deleted test | Now |
|---|---|---|
| Path aliases (symlink, hardlink, dot-dot, manifest path equal to the source) are refused before any write, leaving the original untouched | `legacy_import_test` "aliases are rejected before publication…", importer halves of `review_corrections_test` and `unified_contract_test` alias tests | **Covered** for the store: the Gateway halves of those tests, `PathIdentity`, and the namespace-reservation test in `authority_test` |
| An offline tool holds the same exclusive owner as the Gateway and is refused while the Gateway runs | `legacy_import_test` "import owns the store offline…" | **Covered:** `DurableStore.Owner` tests (two OS owners, stale PID is not authority) |
| A multi-step write that fails midway (injected interruption, or its input mutated under it) rolls back every retained row, and a rerun is idempotent | `legacy_import_test` "interrupted import rolls back and reruns…", "archive mutation during import rolls back…", "rerun is idempotent…" | **Covered** for Core commits: `sync_fault_test`, `atomic_bundle_test`, `protected_primitives_test` |
| A crash-safe file write: temp file, fsync, synced intent, rename, recovery that discards an uncheckpointed temp and completes a synced one, never exposing partial JSON | `atomic_file_test` (three tests) | **Gap, no owner yet:** the manual lane writes its packet with a plain `File.write` (`manual_lane/cli.ex:380`) and appends `operator.log.jsonl` unsynced (`manual_lane/log.ex:184`). A torn packet or log line after a crash is possible; `ci.ex` uses temp+rename without fsync |
| Unknown fields and unsupported versions fail closed with the input preserved as evidence; malformed, non-UTF-8 and oversized JSON are refused, not truncated | `schema_test` "fails closed on unknown authority fields…", "contains malformed, non-UTF8, and oversized JSON artifacts" | **Covered** for Core records: `RecordCodec` strict decoding (`:unknown_field`) in `record_codec_test` and `gateway_test`. Lane inputs (`WorkPacket`, receipts) are covered by their own decoders in `manual_lane/*_test` |
| Frozen evidence is bound to source SHA-256 and loaded BEAM MD5; a changed loaded implementation or another revision refuses every positive result | `h0_accepted_fr07_boundary_test` (six tests) | **Covered:** `fr08a_protected_boundary_test` "changed loaded Gateway implementation refuses all positive evidence" and "revision mismatch cannot claim readiness". The dated H0 report stays under `docs/fr-08` as history |

CI no longer fetches full history: only the H0 tests read the `pramana/<sha>` tags. The tags
stay until the operator deletes them.
