verdict: correction

# ML-DEL-DAEMON review notes
Reviewer: agent:claude-fable-5-1/review-ML-DEL-DAEMON (independent; did not write the change)
Candidate 65e1fa37cc98575236e566d01be4cfb0d431a16f (5 commits) on base db4334c34915c0e9d34723a5b6078b1a2c4b782f
Worktree: /private/tmp/review-ML-DEL-DAEMON (detached at the candidate; left clean)

One correction (F1), everything else is low or informational. The deletion itself is sound:
the forward path compiles, releases and passes 769 focused tests; no live reference to the
deleted stack remains; the knowledge record is thorough; scope is respected.

## Findings

### F1 — medium, correction: `Effects.ProcessGroup.signal/4`'s refusal branch is untested
- lib/foundry/effects/process_group.ex:83-92 (`{:error, :stale_identity}` on a mismatched
  or absent identity) — the guard that stops a recycled pid or a replacement owner from being killed.
- `grep -rn stale_identity test` → no hits. Before the deletion it was covered only by
  test/foundry/checks/runner_test.exs "a stale identity (already exited) is refused rather
  than signalled" and "a replacement-owner mismatch (same pid, wrong recorded start time) refuses to
  signal a live process" (`git show db4334c:…runner_test.exs` :104-139).
- The kept test/foundry/effects/process_group_test.exs covers presence (`gone?`, defunct,
  zombie, recycled) and a failed `kill` (:127), but never the refusal.
- The MOVED-KNOWLEDGE note ("Gap, owner FR-10") is not enough here: this is a kept module's safety
  property, not future-owner knowledge, and it is pure logic. Two tests with the file's existing
  `marker_process/1` fixture, the real `identity/1`, and a `command_runner` that flunks if called
  (no real signal is sent because the refusal precedes `kill`) cover both cases:
  (a) forge `started_at` on a live marker → `{:error, :stale_identity}`;
  (b) close the marker port, wait for `gone?`, then `signal/4` → `{:error, :stale_identity}`.
  The positive real-SIGTERM path may stay a disclosed gap; signalling a live pid inside the test VM
  is the hazard the file's own header names.

### F2 — low: a release started without `FOUNDRY_MANUAL_LANE=1` is a silent idle daemon
- lib/foundry/application.ex:31,39 and bin/foundry-lane:20 agree: the script exports the flag,
  `startup_mode/0` reads it. Verified on the built release: `daemon` without the flag →
  `Supervisor.which_children == []`, node stays up under `+heart` until `stop`, prints nothing;
  with the flag → `[ManualLane.Server]`.
- Acceptable for this ticket (the runbook routes operators through bin/foundry-lane), but a foot-gun
  for `bin/foundry daemon|start` run by hand. rel/overlays/env.sh already branches on
  `RELEASE_COMMAND` (the release script exports it), so either defaulting the flag there for
  `daemon*|start*` or a one-line `IO.puts` in `runtime_children(:client)` when RELEASE_COMMAND is a
  boot command closes it. Base printed a "client mode" line; the candidate prints nothing.

### F3 — low: non_launch allowlist admits any `System.cmd("git", …)`, not only reads
- test/foundry/manual_lane/non_launch_test.exs:96 `allowed_spawn?(_mod, {System, :cmd, "git"})`.
  The moduledoc says "a literal `git` read", but argv is not inspected: `git worktree add`,
  `git -c core.sshCommand=…`, or an alias with `!` would pass. Real closure hits are read-only today
  (manual_lane/cli.ex:435 rev-parse; git_evidence.ex:89 merge-base, :100 generic helper for
  status/rev-parse). Capacity's dynamic `df` allowance is module-scoped and fine. Note only; tightening
  needs git_evidence's `git/2` helper to take a literal subcommand.
- Red controls: the four fixture controls pass, and a live control bites: inserting
  `System.cmd("omp", ["run"])` into ManualLane.CLI.main/1 fails the closure test with
  `[{Foundry.ManualLane.CLI, {System, :cmd, "omp"}}]`; restored by exact string, 5/5 green.

### F4 — low: edge cases in deleted tests not named in docs/design/MOVED-KNOWLEDGE-2026-09-23.md
Spot-checked 16 deleted files by test name and 4 by body. Unrecorded (add a phrase to the owner row):
- checks/runner_test "the published child PID is bound to its launch token and owns a separate
  process group" — the setsid-per-launch rule that makes `kill -<pgid>` correct (FR-10 row).
- checks/runner_test "sanitize_env redacts values while preserving which keys were declared"
  (redaction row, alongside telemetry).
- agent_server_test "agent-start failure never adopts a replacement process after the pre-start
  baseline" — the adoption side; the doc records only the cleanup side ("recycled or foreign occupant
  survives") (FR-10 row).
- coordinator/engine_test "queued tick and handoff complete in either mailbox order without losing the
  handoff" (FR-10 row).
- coordinator/recovery_test "dirty task checkout is refused on handoff" — the code survives at
  lib/foundry/git_evidence.ex:66-73 but `grep -rn 'uncommitted or untracked' test` → none;
  name it in the ML-GITEVIDENCE-TEST gap row.
Covered without being listed (fine): runtime_startup_boundary_test "actual client startup is
effect-free" → manual_lane/startup_test "without it the node is a child-less client".

### F5 — info: scope
- Only commit 65e1fa3 touches an out-of-scope file, docs/AUDIT-2026-09-12.md: 61 relative links to
  deleted source replaced by GitHub blob URLs pinned at db4334c, no prose change. Forced by the
  0-broken-links AC on a historical record; acceptable. (check_docs checks relative links only, so
  the pins are now unchecked — intended for an archive.)
- Every other file in the 5 commits is inside the packet's scope globs. Assessor/Relocation/FR-19A
  untouched (ML-DEL-LEAVES).

### F6 — info: kept vs sweep, archive
- `Schema` and `AtomicFile` kept against sweep §1.1 row 67: their only lib callers are
  durable_store/legacy_import.ex and legacy_line.ex, which AC #2 forbids touching; disclosed in
  e858bbc's message and docs/CI.md. Correct. `Checks.*` deleted per sweep Q5; `ProcessGroup` kept.
- FR-15aA (77b69b2): 6 files moved unchanged (`git show --stat` shows 0-line renames), test renamed
  `.exs.txt` so it does not compile; .formatter.exs inputs are `{config,lib,test}` so docs/archive is
  not format-checked; nothing under lib/test/ci/bin references the archived files; ci.ex drops the
  `python_tiktoken_recompute` exclusion whose only user (projections/benchmark_test) is deleted.
  docs/fr-15a/provisioning-specification.md keeps the historical `elixir ci/validate_fr15aa.exs`
  command under its "Archived 2026-09-23" banner; fine as record. FR-08A attestation: repair tests
  green without rebind.

### F7 — info: dangling references
`git grep -nE 'Coordinator|AgentServer|Herdr|Improver|HardeningPM|Scheduler|COORDINATOR_TICK|PRAMANA_STARTUP_MODE' -- lib test bin ci config mix.exs rel`
→ 14 hits: lib/foundry/ci.ex:78 and 7 tests clear `COORDINATOR_TICK`/`HERDR_ENV` in subprocess
env (hygiene, could go later); startup_test.exs:14,42 asserts the retired switch is inert; three
comments. No live module reference.

## Acceptance criteria
1 delete list — met (157 files, −25,300 lines; every named subsystem gone; roles/, config/schemas, bin stubs).
2 kept set — met; LaunchEligibility tests moved verbatim (first 62 lines identical; final test completed
  with `select_profile/3` in place of `AgentServer.init/1`).
3 lane-only CLI/Application/config — met (cli/rpc.ex dispatches `lane` only; config.exs keeps only
  runtime_root; rpc_test 9, startup_test in manual_lane 66).
4 non_launch retarget — met, red controls bite (F3 note on breadth).
5 FR-15aA archive — met (F6).
6 MOVED-KNOWLEDGE — met, with F4 additions requested.
7 docs routing, check_docs 0, compile clean, focused tests green — met.

## Checks (review worktree; TMPDIR=/private/tmp, MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps)
- MIX_ENV=test mix compile --force --warnings-as-errors: exit 0 (80 files).
- MIX_ENV=prod mix release --path /private/tmp/review-daemon-rel --overwrite: exit 0.
- Release smoke: `daemon` without flag → children []; with FOUNDRY_MANUAL_LANE=1 + repo/policy/store env
  → [ManualLane.Server]; `stop` exit 0 both times (unique RELEASE_NODE/cookie).
- elixir bin/check_docs.exs: 0 broken links, exit 0.
- mix test, serial, one target per run, all exit 0: manual_lane 66, durable_store 296, workflow 303,
  repair 23 (fr08a_protected_boundary, fr08_handoff_gate, h0), architecture_boundary 13, rpc_wrapper 8,
  cli/rpc 9, launch_eligibility 5, effects 11, ci_test 11, boundary 3, quota 4, atomic_file 3, schema 6,
  runtime_root 8. Total 769 passed, 0 failures.
- Live red control on non_launch_test: 4/5 with the injected spawn, 5/5 after exact-string restore;
  `git status --short` empty afterwards.
- Not run: ci/run.exs (per instructions); the two ML-DEL-LEAVES directories (assessor, relocation).
