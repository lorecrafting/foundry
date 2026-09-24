# Dogfood log: the manual lane

The operator's running record of Foundry work driven through the manual lane
([runbook](LANE-RUNBOOK.md)). One entry per ticket, then the frictions found in the lane,
its tooling or the runbook. The lane store is the authoritative trail (`bin/foundry lane
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
| ML-RENAME-NS | `b30d0a2` | `ff0b5d5`, then `f4ca196` | [correction](reviews/ML-RENAME-NS.review-1.md) (the regex made the rename's own descriptions tautological), then [approved](reviews/ML-RENAME-NS.review-2.md) | batch B1 + FR-08A rebind | FR-23b rename 1/3, 314 files. Operator exception: pinned-commit permalinks in `archive/AUDIT-2026-09-12.md` keep their old paths (rewriting them 404s). The developer opened a copy of store 2 with the renamed build: `mode: :ready`, so no rotation here |
| ML-RENAME-BIN-ENV | `9c7fe01` | `c73b6ea` | [approved](reviews/ML-RENAME-BIN-ENV.review.md) | batch B2 | FR-23b rename 2/3: the wrapper is `bin/foundry`, five env vars are `FOUNDRY_*`, no aliases. Retired Pramāṇa-only `bin/pramana-*` script names left for the archive drop (Q10). Reviewer: `FOUNDRY_STARTUP_MODE` has no reader (batch C dead vocabulary) |
| ML-DOCS-ARCHIVE-DROP | `ecdbc84` | `29185be` | [approved](reviews/ML-DOCS-ARCHIVE-DROP.review.md) | batch B3 | Q10: `docs/archive` (138 files) deleted; 67 inbound links are permalinks at tag `records/2026-09-24`, all verified at the tag. `pramana` matches 675 → 197 |

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
| Q7 | Do the Pramāṇa-era env names and wrapper keep working as aliases after the rename? | **Decided 2026-09-24: hard rename, no aliases** |
| Q8 | Should agents run their own lane commands? | **Decided 2026-09-24: from batch C**, developer and reviewer agents run `lane submit` / `lane review` under their packet's principal; the operator still admits, issues packets and integrates |
| Q9 | Start budget for the store seeded at the ML-RENAME-DOMAIN-TAGS rotation | **Decided 2026-09-24: 50 developer / 50 reviewer starts** (`lane-policy.example.json`), so batch C can run about four developers in parallel; a policy-revision command stays deferred until that runs out |
| Q10 | Keep dated records (`docs/archive`, fr-08 evidence) in the tree? | **Decided 2026-09-24: no.** Tag `records/2026-09-24` at `b30d0a2` (the last commit before the renames, so the records keep their original names), delete `docs/archive`, and turn inbound links into permalinks at the tag. `docs/fr-08` gets the same treatment in batch C's triage; reviews and this log stay. Supersedes Q6 for those records |

## Frictions

| # | Where | What happened | Candidate fix |
|---|---|---|---|
| F1 | `bin/foundry lane …` | Every command prints the daemon's `[info] lane <cmd> started/finished` log lines around its result, so output needs filtering before it can be read or parsed | keep lane command logging off the RPC client's stdout, or only at debug |
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
| F14 | `lane submit` | The candidate must be the checkout's `HEAD`. To drop a developer's trailing commit (it broke 62 permalinks), the operator had to `reset --hard` the developer's own worktree before submitting | let `submit` take a candidate that is an ancestor of a clean checkout's `HEAD`, or brief developers to leave optional commits on a side branch |
| F15 | renaming the release | After the release rename, `bin/foundry-lane` and `bin/…` look for `rel/foundry` and cannot reach or stop the running daemon built as the old release. Order: `lane integrated`, stop the daemon with the old scripts, fast-forward `main`, rebuild, start | runbook step for tickets that change the release or RPC entry |
| F16 | operator integration worktree | **Operator error.** A `deps` symlink in the integration worktree made the gate refuse `{:dirty_source, ["?? deps"]}` (`.gitignore`'s `/deps/` does not match a symlink). Cost one gate start | never symlink deps into a gated tree; use `MIX_DEPS_PATH` |
| F17 | refusals | Every refused lane command also prints an Elixir `RuntimeError` stack trace from `cli.ex:86` on stderr; stdout and the exit code are right | print the refusal and exit non-zero without raising |

## Scorecard

Is the lane worth running? One row per ticket, filled at integration. **Caught** = defects a
review found (H/M/L); **escaped** = defects the review passed that a rebind, gate or CI then
found; **rounds** = reviews to approval; **lane caught / blocked** = refusals that stopped a
real error / refusals that stopped legitimate work. Frictions: F1–F13 in store 1's nine tickets,
F14–F16 in store 2's first two.

| Ticket | Rounds | Caught | Escaped | Lane caught / blocked |
|---|---|---|---|---|
| ML-CONTRACT-DIVERGENCES | 1 | 0 | 0 | 0 / 0 |
| ML-RUNTIME-PATHS | 1 | 1 L (Q2) | 0 | 0 / 0 |
| ML-WORKFLOW-DIR | 1 | 1 L (Q3) | 0 | 0 / 0 |
| ML-DEL-DAEMON | 2 | 1 H (a guard lost its only test), 1 M (pre-existing flake) | 0 | 0 / 0 |
| ML-DEL-LEAVES | 1 | 1 L (out-of-scope edit, F8) | 0 | 0 / 0 |
| ML-DEL-LEGACY-IMPORT | 1 | 0 | 2 (F12: identity-negative fixture, `ci_test` pin) | 0 / 0 |
| ML-DOCS-ARCHIVE | 1 | 0 | 0 | 0 / 0 |
| ML-LANE-FRICTIONS | 1 | 0 | 0 | 0 / 0 |
| ML-PROCESS-GROUP-TESTS | 1, then carried over | 1 L (stale safety comment) | 0 | 0 / 1 (`allocation_unavailable`, F7) |
| ML-PROCESS-GROUP-TESTS-2 | 1 | 0 | 0 | 0 / 0 |
| ML-RENAME-NS | 2 | 1 L (tautologies) | 0 | 0 / 0 |
| ML-RENAME-BIN-ENV | 1 | 0 (3 informational notes) | 0 | 0 / 0 |
| ML-DOCS-ARCHIVE-DROP | 1 | 0 (2 pre-existing stale prose paths) | 0 | 0 / 0 |

**Reading, 2026-09-24 (11 tickets, before ML-RENAME-BIN-ENV).** Independent review pays: 7 defects caught, one of them
high, against 2 escapes. The lane itself has caught no real error yet and has blocked one
legitimate step. That is expected while the operator runs every lane command: the lane has
been a trail, not a boundary. Frictions have not fallen (three in store 2's first two tickets),
and nearly all sit at the manual edges (submit, integration, store rotation), not in Core.

**Changes from batch C (operator decision Q8):** developer and reviewer agents run their own
`lane submit` and `lane review` under their packet's principal, so the principal and
independence rules are exercised against the agents; and failure drills (below) test whether the
lane refuses or only records. Judge again after batch C.

## Drills

| # | Drill | Expected | Observed |
|---|---|---|---|
| D1 | `submit` by a principal that did not issue the packet | refuse | `receipt_provenance_mismatch` ✓ |
| D2 | reviewer packet before any submit | refuse | `wrong_source_phase` ✓ |
| D3 | `submit` from a dirty checkout | refuse | `git_evidence`, names the modified file ✓ |
| D4 | candidate that only touches a file outside `scope` | accepted (A4: scope unchecked) | accepted, `awaiting_review` — record only; the reviewer is the only scope check |
| D5 | the developer principal asks for the reviewer packet | refuse | `principal_not_independent` ✓ |
| D6 | a principal other than the reviewer packet's issuer records the review | refuse | `receipt_provenance_mismatch` ✓ |
| D7 | review names a candidate other than the submitted one | refuse | `candidate_mismatch` ✓ |
| D8 | `kill -9` the daemon while a reviewer packet is issued, restart | fenced until attested recovery | every command refused with `ambiguous_previous_owner` and the next step; `recover --evidence` → `ready`; ticket state intact ✓ |
| D9 | use the pre-crash reviewer packet after recovery | works | review recorded (`rejected`) ✓; a second review → `review_already_recorded` ✓ |

Drills ran 2026-09-24 on throwaway ticket ML-DRILL-1 in store 2 (rejected, never integrated).
Every refusal also prints an Elixir `RuntimeError` stack trace on stderr (F17); stdout and the
exit code are clean. D4 is the lane's one gap exercised here, and D1/D6 show the principal check
works only because principals are self-declared strings (A3): an impostor who types the right
principal passes.
