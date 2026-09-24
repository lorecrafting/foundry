approved

Review of ML-LANE-FRICTIONS-2, candidate 6cf04a5f57b0d8bd462bbed33859074b5646cb97 (base b9d8311).
Reviewer: agent:claude-fable-5-1/review-ML-LANE-FRICTIONS-2, detached worktree /private/tmp/review-ML-LANE-FRICTIONS-2.

## Findings (ranked)

None blocking. Two notes, neither requires a change to the candidate:

1. Note (F13 record vs. code). At base, the refusal render sorted keys, so `lane integrated ML-9`
   printed `refused / detail: - / error: ticket_not_found` (lib/foundry/manual_lane/cli.ex base
   :590-598): the atom did print, after the detail. The developer's "could not reproduce" is
   consistent with the code; the F17 stack trace on stderr most likely hid the line when F13 was
   logged. The new single clause (cli.ex:595-596) puts `error:` before `detail:`, which is the
   right fix for a detail that can run to many lines. Acceptance criterion met either way.

2. Note (F18 trade-off, by design). bin/check_docs.exs:16 now resolves against the working tree,
   so a link to an ignored or untracked file passes locally but fails in CI
   (.github/workflows/foundry-ci.yml:31 runs it on a clean checkout). Acceptable: that is what
   F18 asked for, and only tracked `*.md` files are scanned, so untracked noise cannot add checks.

## Attack results

1. `exit({:shutdown, 1})` cannot take down the daemon.
   - Only caller of `ManualLane.CLI.main/1` outside tests: lib/foundry/cli/rpc.ex:33 (`RPC.run/1`),
     reached via `bin/foundry` -> release `rpc` -> `elixir --rpc-eval`.
   - Elixir 1.20.3 (pinned in mise.toml; the lane build bundles elixir-1.20.3):
     Kernel.CLI `process_command({:rpc_eval, ..})` (lib/kernel/cli.ex:429-451) does
     `:erpc.call(node, Kernel.CLI, :rpc_eval, [expr])`; the daemon-side `rpc_eval/1` (:121-125)
     catches every kind/reason inside the erpc-spawned process and returns `{kind, reason, stack}`;
     the client re-raises it and `exec_fun` (:143-145) turns `{:shutdown, int}` into halt(int)
     with no output. The daemon-side process is erpc-spawned, unlinked, and the exit is caught
     before it ends the process anyway.
   - Empirical, two throwaway nodes (no daemon contact): `--rpc-eval 'IO.write("refused\n..."); exit({:shutdown, 1})'`
     -> status 1, stdout intact, 0 bytes on stderr; the old `raise` -> status 1 plus a 3-line
     stack trace; the server node answered afterwards; the eval process on the server reported
     `links: []`, monitored only by the remote client pid.
   - In-process callers (cli_test.exs:79-101, restart_drill_test.exs:543-548) wrap `RPC.run` in
     `catch :exit, {:shutdown, 1}` inside the capture_io fn. test/foundry/cli/rpc_test.exs:157
     expects `ArgumentError` on transport rejection, untouched by this change.
   - ManualLane.Server is only ever reached by GenServer.call from that process; no monitor or
     link on the caller.

2. Exit status end to end. bin/foundry:80-84 (unchanged) propagates the release `rpc` status.
   rpc_wrapper_test.exs:285-294 drives the real wrapper with a fake release that evals the
   RPC code in a local BEAM: status 1, output `refused\nerror: lane_disabled\ndetail: -\n`, no
   `** (`. `--json` render (cli.ex:590) unchanged; `lane/1` helper still asserts JSON `ok`
   matches the exit.

3. Red control: see below (raise restored at cli.ex:89, three files rerun, edit reversed).

4. bin/foundry without fallbacks. Resolution is `foundry-lane env` (sibling of the script, so any
   checkout or worktree) -> FOUNDRY_LANE_BUILD default /private/tmp/foundry-lane-build, whose
   release exists and is executable. Error paths exercised from the worktree without contacting
   the daemon: missing build -> 69 with the path; explicit bad FOUNDRY_RELEASE wins -> 69;
   non-lane argv or no argv with nothing set -> 64. No doc still points at `_build/prod/rel`
   (grep over README, docs/*.md, docs/batch-d/*.md, bin, ci).

5. check_docs. Clean at candidate: 0 broken, exit 0. `git ls-files -- '*.md'` = 121 = grep count.
   Forced broken link in README -> `README.md: nope/missing.md`, exit 1; reversed, `git diff
   --exit-code` clean. Link to an untracked .md -> 0 broken (F18). Untracked `docs/noise.txt`
   and untracked `docs/noise-untracked.md` containing a broken link -> 0 broken (not scanned).

6. Runbook. F7 step matches the record at DOGFOOD-LOG.md:43-44 (`foundry-lane.store1-archived-2026-09-24`)
   and the FOUNDRY_RUNTIME_ROOT default (LANE-RUNBOOK.md:30). F15 order matches DOGFOOD-LOG.md:86.
   F14 text matches the `git_evidence` refusal (LANE-RUNBOOK.md:187). Permalinks: tag
   records/2026-09-24 holds docs/archive/fr-04/ (21 files) and docs/archive/fr-06/storage_spike.py;
   HTTP 200 for all three URLs. README:5: exactly two `pramana/*` tags exist; `grep -rn 'pramana/'
   test lib` is empty.

7. Scope: all 10 changed paths are inside the packet's `scope`. One commit, tree clean.

## Commands run

- Focused tests at candidate (fresh MIX_BUILD_PATH, TMPDIR=/private/tmp): cli_test,
  restart_drill_test, rpc_wrapper_test, cli/rpc_test -> 54 passed, 0 failed, 25.7 s. One
  `:eisdir` warning is the deliberate fixture at cli_test.exs:551.
- Red control: cli.ex:89 `exit({:shutdown, 1})` replaced by the base `raise`, same three lane
  files rerun -> 21/45 passed, 24 failed, including both new tests (rpc_wrapper_test "a refused
  lane command exits 1 through the wrapper without a stack trace" and cli_test "F13/F17: a
  human-readable refusal leads with its atom and exits without raising") and every refusal
  path in restart_drill_test via the shared `catch :exit` helper. Exact string reversed;
  `git diff --exit-code` clean.
- elixir bin/check_docs.exs: 4 runs (clean 0 / broken 1 / untracked-link 0 / noise 0).
- Two-node --rpc-eval experiment (snames revfr2srv/revfr2c*), killed afterwards.
- curl: 3 permalinks, all 200.
- FR-08A not run: no pinned file changed (diff touches none of the nine protected modules).
