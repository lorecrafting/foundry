approved

Reviewer: agent:claude-fable-5-1/review-ML-FR08-TRIAGE, worktree /private/tmp/review-ML-FR08-TRIAGE
Candidate 7e4621ebeb54e9bbb701000f93baa475b1081588 (base b9d8311). 72 files changed, 58 deleted, 1 added, 13 modified.

## Findings (by severity)

Blockers: none.

Corrections required: none.

Observations (no action required by this ticket):

1. Minor. 20 non-link line citations of deleted files (`fr08b-kernel-correction-design.md:235-241` style, in backticks) remain in kept docs: docs/fr-08/FR08B-SUBCOMMIT2-DECIDE-DESIGN-2026-09-23.md (12: lines 43, 64, 186, 197, 202, 208, 222, 245, 268, 288, 292, 330), docs/fr-08/FR08B-SUBCOMMIT3-DESIGN-2026-09-23.md (3: 56, 90, 117), docs/DOGFOOD-READINESS-2026-09-23.md (2: 60, 65), docs/fr-10/FR10-DESIGN-2026-09-23.md:227, docs/fr-08/fr08b-pure-kernel-review.md:194 (the "commands run" table names `docs/fr-08/fr08b-pure-kernel-review-probes.exs`), docs/fr-08/fr08b-sweep-2026-09-21-raw.txt:2. They are not Markdown links, so check_docs cannot see them and the acceptance criterion ("links ... become permalinks") does not cover them; docs/fr-08/README.md's closing sentence tells a reader where the targets went. Acceptable as-is.
2. Nit. Commit message says "12 links rewritten"; I count 13 permalink occurrences on added lines (11 distinct targets, one of which is the `tree/.../docs/fr-08` directory link in the new README). No effect on the verdict.

## Attack results

1. Deleted files carrying weight: `git grep -n -F <basename>` for all 58 deleted basenames across lib test bin ci spec mix.exs config .github AGENTS.md README.md: 0 hits. `git grep -F docs/fr-08 -- lib test bin ci spec ...`: 19 hits, every target is a kept file (16 distinct, all present). Directory readers (`Path.wildcard|File.ls|File.read|File.stream` in lib test bin ci spec, filtered to docs): only bin/check_docs.exs (tracked-file scan) and the fr08a protected-report read; no glob over docs/fr-08. `h0-accepted-fr07-report.txt` (which the sweep at CLEAN-ROOM-SWEEP:128 listed as read by two tests) is safe: `git grep -il 'h0_accepted\|H0Accepted' -- lib test bin ci` returns nothing; the H0 module and its test are already retired at base.
2. Keeps: every one of the 21 non-README kept files has a code citer (lib/test/bin/spec) or a load chain to one: fr08a-final-review-probes.exs is `File.read!`-ed by three kept probes and fr08a-typed-replay-review-probes.exs by the correction probe (both run by test/foundry/durable_store/fr08a_rereview_matrix_test.exs); workflow-definition-seam.md is cited by docs/REPAIR-PLAN.md:195,266 and docs/orchestrator/O1-SEQUENCING-PROPOSAL-2026-09-23.md:73. No keep is history-only.
3. Permalinks: 11 distinct `records/2026-09-24/...` targets on added lines, 11 resolve (`git cat-file -e records/2026-09-24:<path>`), 0 missing. All 52 distinct `records/2026-09-24/` targets in the tree resolve. All 58 deleted paths exist at the tag (58/58). Tag object e509dc26.
4. Allowlist: §5.1 table (34 rows) vs `git grep -il pramana` (34 files): `diff` identical. New entries: docs/batch-d/reviews/ML-RENAME-DOMAIN-TAGS.review.md quotes retired `pramana-foundry-*` names in a rename record (lines 15-32); docs/fr-08/fr08b-pure-kernel-review.md:21 records the worktree path `/private/tmp/pramana-fr08b-kernel.bYbL8q` from the pre-split checkout. Both genuine, neither un-renamed vocabulary. Only `pramana` line in kept docs/fr-08 is that one.
5. README: claims checked (test/script readers, probe load chain, code citers, seam note citers) all hold. `elixir bin/check_docs.exs`: 0 broken link(s), exit 0. docs/batch-d: 0 changed paths. Scope: 0 paths outside `docs`, `README.md`, `AGENTS.md`. Worktree clean (`git diff --exit-code`).

## Commands run

- `git diff --name-status b9d8311 7e4621e`: 72 files (58 D, 1 A, 13 M); out-of-scope 0; docs/batch-d 0.
- basename greps of the 58 deleted files over lib test bin ci spec mix.exs config .github AGENTS.md README.md: 0 hits.
- `git grep -n -F docs/fr-08 -- lib test bin ci spec ...`: 19 hits, all kept files.
- `git cat-file -e records/2026-09-24:<path>`: 11/11 added targets, 52/52 tree-wide targets, 58/58 deleted files.
- §5.1 vs `git grep -il pramana`: identical, 34 = 34.
- `elixir bin/check_docs.exs`: 0 broken link(s).
- `TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps mix test test/foundry/durable_store/fr08a_rereview_matrix_test.exs test/foundry/repair/fr08a_protected_boundary_test.exs test/foundry/workflow/kernel_test.exs`: 140 passed, 0 failures (FR-08A green: no pinned lib file changed).

Not run: ci/run.exs, full suite, bin/coverage_guided_sweep.exs (its only fr-08 input, the raw sweep file, is kept and its path unchanged).
