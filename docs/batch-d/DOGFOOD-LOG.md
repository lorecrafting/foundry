# Dogfood log: the manual lane

The operator's running record of Foundry work driven through the manual lane
([runbook](LANE-RUNBOOK.md)). One entry per ticket, then the frictions found in the lane,
its tooling or the runbook. The lane store is the authoritative trail (`bin/pramana lane
log`); this log records what the operator saw and decided.

Roles: operator = an LLM session (Claude Opus 5.5); developer = a worktree agent
`agent:claude-opus-5-5/dev-<ticket>`; reviewer = a fresh Fable agent
`agent:claude-fable-5-1/review-<ticket>`, never a fork. Integration is manual: cherry-pick
onto `main`, one gate run per push.

## Setup, 2026-09-23

- Lane built and started with `bin/foundry-lane build` / `start` from `main` at `55037db`,
  fresh store under `~/.local/state/foundry-lane`, example policy (10 developer and 10
  reviewer starts for the store). `lane status`: `mode: ready`.
- Before the lane could run, the split cleanup landed directly (not through the lane):
  `FOUNDRY_MANUAL_LANE_REPO` defaulted to the checkout's parent, which no longer holds the
  repository.

## Tickets

| Ticket | Base | Candidate | Review | Integrated | Notes |
|---|---|---|---|---|---|
| ML-CONTRACT-DIVERGENCES | `55037db` | `05e2f3c` | [approved](reviews/ML-CONTRACT-DIVERGENCES.review.md) | `93fb057` | record the four ledger/control divergences in the workflow contract. Developer verified all four against the code; found the B3 readings proposal's "no layer refuses issue under pause" is stale (the kernel now refuses, `control.ex:40-44`), left as a dated record |
| ML-RUNTIME-PATHS | `55037db` | `7a9b435` | [approved](reviews/ML-RUNTIME-PATHS.review.md), one low finding (Q2) | `1ae3c3b`, `8e61cd9` | agent prompts and generated scopes lose `foundry/` and `workflow/`. Developer also dropped `cd workflow &&` from generated checks and narrowed HardeningPM's leak check to `lib/foundry/`; found `preparation.ex:6` (`cwd: "workflow"`) and `local_exclude.ex:12` (`workflow/local/`) out of scope → next ticket |
| ML-WORKFLOW-DIR | `55037db` | `3fece1a` | [approved](reviews/ML-WORKFLOW-DIR.review.md), one low finding (Q3) | `25f7174` (batch 1) | Preparation's deps.get runs at the root; LocalExclude defaults to `local/`. No `lib/` caller reaches `Preparation.commands` or the Pramāṇa-shaped database checks |
| ML-DEL-DAEMON | `db4334c` | `65e1fa3`, then `742a60d` | [correction](reviews/ML-DEL-DAEMON.review-1.md) (the `ProcessGroup` `:stale_identity` guard lost its only test; five more edge cases for the knowledge note), then [approved](reviews/ML-DEL-DAEMON.review-2.md) | batch A1 | lib 45.5k → 31.8k lines before ML-DEL-LEAVES; lane-only CLI and Application; FR-15aA archived; [moved knowledge](../design/MOVED-KNOWLEDGE-2026-09-23.md). The rereview found a pre-existing flaky `process_group_test` case → follow-up ML-PROCESS-GROUP-FLAKE |
| ML-DEL-LEAVES | `db4334c` | `61b2c3e` | [approved](reviews/ML-DEL-LEAVES.review.md) (one disclosed out-of-scope deletion accepted, F8) | batch A1 | retire the Assessor, Relocation and the FR-19A sync-EIO workflow (C3) |
| ML-DEL-LEGACY-IMPORT | `5fb7603` | `e23075e` | [approved](reviews/ML-DEL-LEGACY-IMPORT.review.md) | batch A2 + FR-08A rebind | H0, LegacyImport/LegacyLine, AtomicFile, Schema deleted; legacy authority tables now fence startup; CI no longer fetches full history. The rebind found the identity-negative fixture still expecting 7 capabilities (F12) |
| ML-DOCS-ARCHIVE | `5fb7603` | `6761d1b` | [approved](reviews/ML-DOCS-ARCHIVE.review.md) | batch A2 | 37 top-level docs → 14; 137 files under `docs/archive/` and `docs/design/`; new router, archive index and OBSERVABILITY |
| ML-LANE-FRICTIONS | `5fb7603` | `fd208d1` | [approved](reviews/ML-LANE-FRICTIONS.review.md) | batch A2 | F1 quiet stdout, F5 notes archive, F6/F10 `lane integrated`, F4 reviewer worktrees in the runbook |
| ML-PROCESS-GROUP-TESTS | `5fb7603` | `c32df8a` | [correction](reviews/ML-PROCESS-GROUP-TESTS.review-1.md): one stale header comment | carried over | correction packet refused `allocation_unavailable` (F7); re-admit as ML-PROCESS-GROUP-TESTS-2 in a fresh store |
| ML-PROCESS-GROUP-TESTS-2 | `69855d9` | `1f5f487` | [approved](reviews/ML-PROCESS-GROUP-TESTS-2.review.md) | batch PG | store 2's first ticket: `c32df8a` cherry-picked unchanged plus the header-comment correction |

Batch A2 (four tickets, three integrated) was integrated with one conflict resolved by hand (the audit moved while a link in it changed) and one FR-08A rebind commit by the operator.

**Store rotation, 2026-09-24.** Store 1 is exhausted (F7), so it was stopped cleanly and archived at
`~/.local/state/foundry-lane.store1-archived-2026-09-24`. Its trail holds all nine tickets
above. The lane was rebuilt from `ff0e366` and started on a fresh store; `lane status`
prints only its result (F1 verified live).

Batch A1 (the two deletion tickets) was integrated the same way, plus one operator fixup commit for links in docs neither ticket could edit.

Batch 1 (the three tickets above) was cherry-picked onto `integ/lane-batch-1`, then run
through Linux CI on a PR and one local gate before `main` fast-forwarded.

## Operator questions and decisions

| # | Question | Status |
|---|---|---|
| Q1 | The `pramana-foundry-*` digest domain tags are persisted and checked on read (`record_codec.ex:258`); renaming them makes existing stores unreadable | **Decided 2026-09-23: hard rename, fresh stores.** The lane store is archived, not deleted, when that ticket lands |
| Q2 | HardeningPM's scope-leak check (`hardening_pm.ex:235`, `roles/hardening_pm.md`) now means `lib/foundry/` only, so an IMPRV ticket scoped to `test/` blocks its batch. Lib-only, or anything inside the checkout? | open |
| Q3 | LocalExclude's default `local/` is unanchored; `/local/` would match `.gitignore` but breaks `verify_protection`'s pathspec | open, low |
| Q4 | `Preparation`'s `@database_checks` (`ecto.create`) are Pramāṇa-project checks with no Foundry caller: delete, or keep for project profiles? | open |
| Q5 | Clean-room sweep Q1–Q12 ([sweep](../fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md#7-operator-questions)) | **Decided 2026-09-23:** delete the legacy daemon stack and amend the plan ([C1–C4](../REPAIR-PLAN.md#clean-room-amendment)); archive FR-15aA; retire H0 + legacy import, Relocation, FR-19A sync-EIO, Assessor; operator hygiene done (legacy `local/`, `handoffs/`, `ci-artifacts/` removed; 3 worktrees, 2 merged branches and 12 `archive/2026-09-20/*` tags deleted). Q2–Q4 above become moot with the deletions |
| Q6 | FR-23b renames: do dated records (`docs/archive`, reviews, fr-08 evidence, this log) keep the old names? | **Decided 2026-09-24: rewrite everything**; only references to the Pramāṇa repository keep the name |
| Q7 | Do `PRAMANA_*` and `bin/pramana` keep working as aliases after the rename? | **Decided 2026-09-24: hard rename, no aliases** |

## Frictions

| # | Where | What happened | Candidate fix |
|---|---|---|---|
| F1 | `bin/pramana lane …` | Every command prints the daemon's `[info] lane <cmd> started/finished` log lines around its result, so output needs filtering before it can be read or parsed | keep lane command logging off the RPC client's stdout, or only at debug |
| F2 | `.github/workflows/foundry-ci.yml`, AGENTS.md | CI runs only on pushes to `main` and on pull requests, but AGENTS.md said every push; a pushed branch got no run, so Linux CI needs a PR before `main` moves | AGENTS.md corrected; operator opens a PR per integration batch |
| F3 | GitHub CI | The handoff expected one known Linux failure; there were 107 (hardcoded `/private/tmp`, `/bin/zsh`). Linux runs 1229 tests against macOS's 1232: the three darwin-only filesystem tests in `operational_storage_test.exs:489` | fixed in `f8e6b44`; conventions now forbid both |
| F4 | reviewer briefs | Reviewers ran tests in the developer's candidate worktree; one used `git checkout -- .` for a red control (brief forbids it). Nothing uncommitted was lost, but a reviewer can alter the checkout the lane recorded | give each reviewer its own detached worktree at the candidate |
| F5 | `lane review --notes` | The store keeps only the notes' digest; the notes file lives in `/private/tmp` and would be lost | operator copies notes into `docs/batch-d/reviews/`; the lane could archive the notes body |
| F6 | lane end state | Nothing records `integrated` (risk A5): after cherry-pick, `lane status` still says `ready_to_integrate`, and the integrated SHA lives only in this log | an `integrate` command recording the main SHA |
| F7 | lane policy | The seed grants 10 developer and 10 reviewer starts for the whole store, with no way to add more: after batch 1 and batch A1, 5 remain, and the campaign needs about 10 more. Small tickets were merged to save starts. **It bit:** ML-PROCESS-GROUP-TESTS got a one-line `correction`, and `lane packet` refused the correction attempt with `allocation_unavailable`; the ticket carries over to a fresh store as ML-PROCESS-GROUP-TESTS-2 rather than bypassing the lane | a policy-revision command that raises starts, or a runbook step for rotating the store |
| F8 | `lane admit --scope` | Scope is fixed at admission; ML-DEL-LEAVES found `relocation_containment_test.exs` outside it. The only choices are an out-of-scope edit the reviewer must accept, or abandoning the ticket and admitting a new one | a scope amendment recorded as its own event before the packet is issued |
| F9 | reviewer run | The first ML-DEL-DAEMON reviewer died on an API rate limit mid-review. The lane has no record of it; a fresh agent reused the issued reviewer principal, so one principal named two model instances (risk A3). Reviewers now write notes early so a crash leaves partial findings | a `lane packet --role reviewer` re-issue that records the replacement instance |
| F10 | integration | **Operator error.** The ML-DEL-DAEMON correction had two commits; I cherry-picked only the candidate SHA's own commit (`742a60d`), so the reviewed `:stale_identity` tests and knowledge additions (`12aff6c`) missed batch A1 and its gate. Caught by `git cherry main <dev branch>` during worktree cleanup; landed afterwards with its own gate | integrate the range `<previous candidate or base>..<candidate>`, and check `git cherry` is empty before calling a ticket integrated; `lane integrate` (F6) could check candidate ancestry in main |
| F11 | test hygiene | A peer Pramāṇa session reported that `process_group_test`'s zombie fixture leaks an orphaned Python helper on every run (98 found on the operator's Mac); confirmed, 3 from this session's gate | ticket ML-PROCESS-GROUP-TESTS, with the flake the ML-DEL-DAEMON rereview found |
| F12 | expected-red tests and unrun pins | While a protected change awaits the operator's FR-08A rebind, `fr08a_protected_boundary_test` is expected red, and that masked a real failure in the same file: the identity-negative fixture still asserted 7 capabilities. Neither the developer nor the reviewer could tell the two apart. The batch gate then caught a second miss from the same ticket: `ci_test.exs:65` pinned the `fetch-depth: 0` the ticket removed, and nobody ran `ci_test`. Both were fixed in operator integration commits | developer briefs: run the FR-08A test after a scratch rebind in a throwaway worktree, so only real failures remain red; and grep `test/` for every string a ticket deletes from config or workflows |
| F13 | `lane integrated` refusal | An unknown ticket prints `refused` / `detail: -` without the refusal atom the runbook promises (`error: <atom>`) | print the atom like every other refusal |

