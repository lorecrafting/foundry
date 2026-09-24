approved

Ticket ML-WORKFLOW-DIR — reviewer agent:claude-fable-5-1/review-ML-WORKFLOW-DIR
Candidate 3fece1ac97c6512ee3b25b50ca4084a553a91d6f on base 55037dbbdc84eef6105b218d585f855c5f63b123
Worktree: /Users/raymondluong/dev/foundry/.claude/worktrees/agent-a52e366905e5a461d (HEAD == candidate, git status clean after review)

## Scope (A4)

Diff touches 4 paths, all in packet scope:
- lib/pramana_foundry/preparation.ex
- lib/pramana_foundry/relocation/local_exclude.ex
- test/pramana_foundry/policy_test.exs
- test/pramana_foundry/relocation/local_exclude_test.exs
Three in-scope paths untouched (relocation.ex, preparation_test.exs, relocation_test.exs). No out-of-scope edits.

## Acceptance

1. Preparation deps.get cwd "." — lib/pramana_foundry/preparation.ex:6. Test test/pramana_foundry/policy_test.exs:19 `Enum.all?(commands, &(&1.cwd == "."))` is exact; red control below shows it fails on "workflow". Met.
2. LocalExclude default "local/" — lib/pramana_foundry/relocation/local_exclude.ex:12; moduledoc/doc lines 5, 8, 78, 171 updated. Tests at local_exclude_test.exs:76 (`Enum.count(lines, &(&1 == "local/")) == 1`) and :103/:112 (`"local/" in String.split(content, "\n")`) are exact-line checks; red control shows 2 of 3 tests fail on the old pattern. Met.
3. Database checks (ecto.create at ".") unchanged — preparation.ex:8-11 identical to base. Independent finding: `Preparation.commands/1` has no callers in lib/ at all (only test/pramana_foundry/preparation_test.exs and policy_test.exs), so no Foundry ticket reaches either the workflow or the database checks today. The developer's report on this criterion should say the same; if it claims a runtime path exists, that claim is wrong.
4. Format clean on the 4 touched files; focused tests pass (counts below). I did not run `mix compile --force --warnings-as-errors`; the test compile emitted no warnings.

## Findings

F1 (low, non-blocking, follow-up) — lib/pramana_foundry/relocation/local_exclude.ex:12 vs /.gitignore:6
The exclude pattern `local/` is unanchored: in `.git/info/exclude` it hides a directory named `local` at any depth, whereas the root `.gitignore` uses the anchored `/local/`. Consequences:
- `tracked_ignore_present?/2` (local_exclude.ex:174-186) compares exact trimmed lines, so against this repo's real `.gitignore` (`/local/`) it returns false even though the runtime root is tracked-ignored. It has zero callers (grep lib test), so this is latent, not a live defect.
- No tracked path in the repo has a `local` component (`git ls-files | grep -E '(^|/)local(/|$)'` → empty) and no untracked `local/` dir exists outside deps/_build, so the unanchored pattern hides nothing wanted today.
- Switching to `/local/` is not a one-token fix: `verify_protection/2` (local_exclude.ex:85-88) builds the probe pathspec by trimming only the trailing slash, so `/local/` would yield `git status --porcelain "/local/.probe"`, which git rejects (`fatal: Invalid path '/local'`, exit 128 — reproduced in a scratch repo). Anchoring needs `String.trim_leading(pattern, "/")` on the probe path too.
The packet's acceptance text specifies "local/" verbatim, so the candidate matches the spec as written. Recommend a follow-up ticket: either anchor the pattern (with the probe fix) or delete the dead `tracked_ignore_present?/2`.

F2 (info) — docs/MIGRATION.md:160,237,272 and docs/MIGRATION-TICKETS.md:335 still say `workflow/local/`. Out of scope and historical records; noting only so the count of stale references is on record.

F3 (info) — test/pramana_foundry/relocation/local_exclude_test.exs:47,62,85 use `String.contains?(status, "local/")` (substring). Fixture has no other path containing `local/`, and the exact-line assertions at :76/:103/:112 carry the default-pattern check, so this is not a gap; red control confirms :62 fails on the old default.

## Checks run

- Focused green: `TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps mix test test/pramana_foundry/preparation_test.exs test/pramana_foundry/policy_test.exs test/pramana_foundry/relocation/local_exclude_test.exs test/pramana_foundry/relocation_test.exs` → 7 passed, 1 skipped, 0 failures.
- Red control A (local_exclude.ex:12 temporarily set back to "workflow/local/"): local_exclude_test + policy_test → 3/5 passed; failures at local_exclude_test.exs:62 (`refute String.contains?(status_after, "local/")`) and :103 (`assert "local/" in String.split(content, "\n")`).
- Red control B (preparation.ex:6 cwd temporarily "workflow"): policy_test → 2/3 passed; failure at policy_test.exs:19.
- `mix format --check-formatted` on the 4 touched files → clean.
- Temporary edits reversed by exact string; final `git status --porcelain` empty, HEAD 3fece1a.

## Limitations

- Did not run the full suite, ci/run.exs, or `mix compile --force --warnings-as-errors`.
- Process note: during red control A the command chain included a `git checkout -- .` that reverted the temp edit before the exact-string restore ran. The worktree had no uncommitted work at review start (verified), so nothing was lost, but this violated the standing "reverse the exact string, never checkout" rule; red control B used exact-string restore only.
