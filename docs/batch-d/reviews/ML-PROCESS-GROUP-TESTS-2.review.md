approved
# Review: ML-PROCESS-GROUP-TESTS-2 (candidate 1f5f487 on base 69855d9)
Reviewer: agent:claude-fable-5-1/review-ML-PROCESS-GROUP-TESTS-2
Worktree: /private/tmp/review-ML-PROCESS-GROUP-TESTS-2 (at 1f5f487, `git status --short` empty)

## Verdict
Approved. Carry-over of c32df8a is byte-faithful, the corrected header comment is true
of the code, scope is one file, and the file passes repeatedly with zero orphans.

## Findings
1. Cherry-pick fidelity: `git diff 5fb7603 c32df8a` and `git diff 69855d9 5a83d7b` are
   byte-identical (`diff` exit 0). The file did not change on main between 5fb7603 and
   69855d9 (`git diff --stat 5fb7603 69855d9 -- <file>` empty).
2. Header comment (lines 19-22) is true. The only real signal in the file is
   `stop_helper/2` line 212, `kill -KILL <pid>`: a positive pid, never a process group,
   reached only when `await_gone` fails and `ProcessGroup.presence(identity) == :present`
   re-checks the bound identity of a helper this file spawned. All `ProcessGroup.signal/4`
   calls pass `no_kill/3` (flunks) or a stub runner returning exit 1. The remaining
   `System.cmd` (line 280) runs python, not kill.
3. Scope: `git diff --name-only 69855d9 1f5f487` lists only
   test/foundry/effects/process_group_test.exs.
4. Tests: 5 runs of the file (3 required + 2 to capture the result line), all exit 0,
   `Result: 13 passed`, ~0.4 s each. Orphans (`ps -axo pid,ppid,args | awk '$2==1' |
   grep process-group-zombie`): 0 before, 0 after. No leftover
   /private/tmp/process-group-zombie-* dirs.

Not re-run per instruction: prior review's attacks, gate, full suite.

## Commands run
- `git diff 5fb7603 c32df8a` vs `git diff 69855d9 5a83d7b` via `diff` (identical)
- `git diff --stat 5fb7603 69855d9 -- test/foundry/effects/process_group_test.exs` (empty)
- `git diff --name-only 69855d9 1f5f487` (1 file); `git diff 5a83d7b 1f5f487` (comment only)
- `TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps mix test test/foundry/effects/process_group_test.exs` x5, all `Result: 13 passed`
- orphan sweep x3 (before, after run 3, after run 5): 0 each
