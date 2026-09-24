correction
# Review: ML-PROCESS-GROUP-TESTS (candidate c32df8a on base 5fb7603)
Reviewer: agent:claude-fable-5-1/review-ML-PROCESS-GROUP-TESTS
Worktree: /private/tmp/review-ML-PROCESS-GROUP-TESTS (restored to c32df8a, `git diff --exit-code` clean)

## Verdict
Both defects are fixed at their cause and all three acceptance criteria hold. One
required correction: the file's header comment now states a false safety claim.

### Correction (one line)
`test/pramana_foundry/effects/process_group_test.exs` lines 19-21 still say
"Nothing here ever signals a live pid". After this diff `stop_helper/2` runs
`kill -KILL <pid>` on live helpers. The invariant that matters (never signal a
`ps`-reported *process group*, which could be the BEAM's) still holds; the
sentence does not. Reword to: nothing here signals a process group; the only
pid signalled is a helper this file spawned, after its bound identity is
re-checked in `stop_helper/2`.

## Attack results
1. Linux `ps -o comm=` (reasoned; not run on Linux). procps prints the kernel
   `task->comm`, set at execve from the basename of the path passed to execve
   (never a full path), 15-char cap. On ubuntu-latest it is `python3`, so
   `os.path.isabs` is false and the script falls through to `sys.executable`
   (`/usr/bin/python3`), absolute and executable. Truncation cannot produce an
   absolute path, and `os.access(X_OK)` guards a non-executable one. No re-exec
   on Linux, so the bound command stays stable. Also covers pyenv shims, since
   `sys.executable` is the final interpreter. `sys.executable == ""` is possible
   only on exotic embeds, not CI. On macOS, `comm` is required (measured:
   `sys.executable` is `/Library/Developer/CommandLineTools/usr/bin/python3`,
   itself a shim; `comm` is the Python.app binary).
2. Flake fixed at cause. Probe: `/usr/bin/python3` helper reads back the same
   lstart and a different command 300 ms later; the resolved Python.app binary
   reads identically at 0 and 300 ms. Library finding (not a test issue, not
   blocking): `ProcessGroup.signal/4` compares `command` via `same_process?/2`,
   so any future caller that binds identity on a re-execing launcher
   (`/usr/bin/python3`, `sh -c`) gets `:stale_identity`. Already documented in
   `same_incarnation?/2`'s moduledoc with the cancellation-file backstop; there
   is no `lib/` caller of ProcessGroup today (grep).
3. `stop_helper/2`: kill only runs when `presence/1` is `:present`, i.e. pid,
   pgid and lstart all match the bound identity. Port helpers are group leaders
   (measured: helper pgid == helper pid, BEAM pgid differs), so a recycled pid
   would need the same pid, own-group leadership and the same wall-clock second.
   That is the library's own guarantee. Bounded: grace_ms + 2 s + a few `ps`.
4. Leak regression. Red control: restored the two old Python loops and the old
   on_exit order (touch reap, close port, rm_rf), keeping only the survival
   assertion. Result: 12/13 passed, on_exit failure "helper 39411 survived",
   and one orphan (ppid 1) present. Killed it, reversed the three edits by
   exact string, `git diff` clean. Note: verbatim old cleanup would not be red
   (no assertion existed); the check lives in `stop_helper`'s assert.
   Green loop: 10/10 runs `Result: 13 passed`, orphans 0 before, 0 after,
   0 leftover `/private/tmp/process-group-zombie-*` dirs. Each run ~0.4 s.
5. Scope: one file, `test/pramana_foundry/effects/process_group_test.exs`,
   inside packet scope.

## Commands run
- `TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps mix test test/pramana_foundry/effects/process_group_test.exs` x13 (1 initial, 10 loop, 1 red, 1 post-restore)
- orphan sweep: `ps -axo pid,ppid,args | awk '$2==1' | grep -E 'process-group-zombie|defunct-|stale-'`
