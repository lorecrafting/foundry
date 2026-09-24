verdict: approved

# ML-DEL-DAEMON correction review (attempt 1, review 2)
Reviewer: agent:claude-fable-5-1/review-ML-DEL-DAEMON (independent; did not write the change)
Candidate 742a60d46c3c3748e1031e2330dd6c4def7d2dbf; delta from reviewed 65e1fa3 is 2 commits, 3 files
(docs/design/MOVED-KNOWLEDGE-2026-09-23.md, lib/pramana_foundry/application.ex,
test/pramana_foundry/effects/process_group_test.exs). Worktree /private/tmp/review-ML-DEL-DAEMON,
left clean (`git status --short` empty after every control).

F1 is closed: both refusal branches of `Effects.ProcessGroup.signal/4` are now tested, and each test
fails when its branch is broken. F2 (boot message) and F4 (five edge cases) are done. One
pre-existing flake is disclosed below (R1); it is not introduced by the delta and the new tests are
immune to it.

## Findings

### R1 — low, disclosed, not a correction: pre-existing flake in "a failed signal against a live marker process remains a failure"
- process_group_test.exs:149 (unchanged by the delta). Run 1 of 3 failed with `right:
  {:error, :stale_identity}` where `{:kill_failed, 1}` was expected.
- Cause is the drift the module itself documents (process_group.ex "same_incarnation?" doc):
  `System.find_executable("python3")` is the `/usr/bin/python3` shim, which re-execs into the
  framework Python; `stable_identity/2` accepts two consecutive equal reads, both of which can land
  before the re-exec, and `signal/4` then compares `command` via `same_process?` and refuses.
- Reproduction with `--seed 31118`: HEAD test file 2/8 failed; the 65e1fa3 test file 7/8 failed,
  same test. So it predates the correction (and the ticket: the file was kept verbatim).
- The two new tests cannot flake this way: one forges `started_at` (refused whatever `command`
  reads), the other waits for the port's `:exit_status` (delivered only after the child is reaped)
  and `gone?`, so the reader returns `:not_found`. 13/13 runs of those two green.
- Follow-up (not this ticket): have `stable_identity` wait until `command` stops naming the shim, or
  spawn `sys.executable`'s target directly. Worth a small ticket because it reds the gate at random.

### R2 — info: application.ex boot message
- Elixir's release script exports `RELEASE_COMMAND="$1"` (verified in the built release at
  /private/tmp/review-daemon-rel/bin/pramana_foundry:21-22, Elixir's own template). Values:
  start, start_iex, daemon, daemon_iex, eval, rpc, remote, restart, stop, pid, version.
  `String.starts_with?(_, ~w(daemon start))` matches exactly the four boot commands; `rpc`/`eval`/
  `remote`/`stop` stay silent. `mode == :lane` (flag set) is silent on this line and prints the
  existing "starting: manual lane" from `runtime_children(:lane)`.
- Under `mix test`, RELEASE_COMMAND is unset, so the forced `:client` mode prints nothing;
  startup_test asserts through `runtime_children/1` and never calls `start/2`.
- Note only: `daemon` redirects stdout to the release's erlang log, so a hand-run `daemon` shows the
  line in `tmp/log/`, `start` shows it on the terminal. Acceptable for a foot-gun notice.
- Not rebuilt: the release. The delta changes one `IO.puts`; compile with --warnings-as-errors is clean.

### R3 — info: MOVED-KNOWLEDGE additions
All five F4 items are present with the exact deleted test names, checked at db4334c:
- checks/runner_test.exs:63 "the published child PID is bound to its launch token and owns a
  separate process group" → FR-10 row. Name matches.
- checks/runner_test.exs:193 "sanitize_env redacts values while preserving which keys were declared"
  → redaction row. Body checked: both values become `"[redacted]"`, both keys kept; the doc's
  "values redacted but the declared keys kept" is accurate.
- coordinator/recovery_test.exs:65 "dirty task checkout is refused on handoff and prevents
  promotion" → ML-GITEVIDENCE-TEST gap. Body checked: builds a repo with an uncommitted change and
  expects handoff refusal; the doc points at `git_evidence.ex:66-73`, which is `clean_worktree?/1`
  ("task checkout has uncommitted or untracked changes"). Accurate.
- agent_server_test.exs:270 and coordinator/engine_test.exs:177 names match by grep.

### R4 — info: scope
`git diff --stat 65e1fa3 HEAD` → exactly the 3 files above, all inside the packet's scope globs.
No other file changed; no new dependency; test file's only fixture change is a default-arg
`seconds \\ 30` on `marker_process/2`.

## Checks (review worktree; TMPDIR=/private/tmp, MIX_ENV=test, MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps)
- process_group_test.exs x3 (random seeds): 13/13, 12/13 (R1 test only), 13/13. Exit 0, 2, 0.
- process_group_test.exs --seed 31118 x8 on HEAD: 6 green, 2 red, R1 test only.
- 65e1fa3 test file written over HEAD's, --seed 31118 x8: 1 green, 7 red, R1 test only; restored
  with `git show HEAD:<path> >`, diff empty.
- Red control A (mismatch branch: `same_process?(...) or true`): 12/13, only "a replacement owner
  … is refused, never signalled" fails, with `unexpected kill ["-TERM", "-7162"]` from `no_kill/3`.
- Red control B (`{:error, :not_found}` → `send_group_signal`): 12/13, only "an already-exited pid is
  refused, never signalled" fails, with `unexpected kill ["-KILL", "-7207"]`.
  Both restored from a byte copy of the original; `git status --short` empty, `git diff` empty.
- manual_lane/startup_test + architecture_boundary_test + cli/rpc_test: 26 passed, exit 0.
- mix compile --force --warnings-as-errors: exit 0.
- elixir bin/check_docs.exs: 0 broken links, exit 0.
- Not run: ci/run.exs (per instructions); release rebuild; the wider 769-test set from review 1
  (the delta touches no other module).
