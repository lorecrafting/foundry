approved

# ML-RUNTIME-PATHS review — candidate 7a9b435 on base 55037db

Reviewer: agent:claude-fable-5-1/review-ML-RUNTIME-PATHS (independent of developer). Read-only against
/Users/raymondluong/dev/foundry; tests run from the candidate worktree and a scratchpad copy of base.
Worktree diff base..HEAD is byte-identical to /private/tmp/ML-RUNTIME-PATHS.diff; worktree clean before and after.

## Findings

| # | Where | Severity | Finding |
|---|---|---|---|
| 1 | lib/foundry/hardening_pm.ex:235; roles/hardening_pm.md:18,25 | low, not blocking | Behaviour narrowing beyond the brief. The old check accepted any `workflow/` path, i.e. anything inside the Foundry project (`workflow/test/…` included). The new check accepts only `lib/foundry/`. Consequence: a hand-authored IMPRV ticket whose scope adds `test/foundry/**` now fails `validate_no_scope_leak`, and because the check runs over the whole elaboration batch (`do_review`, line 99), every queued IMPRV ticket in that cycle goes un-elaborated. The batch-wide refusal is pre-existing; the narrower prefix is new. Mitigations: scope is never matched against `changed_files` anywhere in lib/ (coordinator/state.ex:104-133 validates shape only; assignments/handoff.ex checks commands, not paths), the generated default scope never included test/ before either, the change is consistent with roles/hardening_pm.md line 9 ("work exclusively within lib/foundry/"), it is disclosed in the developer report and DOGFOOD-LOG, and it is pinned by hardening_pm_test.exs:19. Doc lines 18 and 25 previously said "outside/inside `foundry/`" (whole project) and now say `lib/foundry/`; that is the same policy choice, not a prefix drop. Operator decision for a follow-up ticket: keep lib-only, or translate faithfully to "inside the checkout" (reject absolute and `../` paths) so hardening tickets can carry a test/ scope. |
| 2 | lib/foundry/improver.ex:469-471, hardening_pm.ex:182-184 | none | `cd workflow &&` removal is correct. mix.exs and mise.toml (erlang 29.0.5, elixir 1.20.3-otp-29) sit at the checkout root; Foundry never executes `required_checks` itself (the only `System.cmd` with a checkout cwd is the CI gate at ci.ex:316), it only requires the handoff's check commands to match the ticket text (assignments/handoff.ex:152-172). Note, out of scope and already logged for the next ticket: preparation.ex:6 still runs `mix deps.get --locked` with `cwd: "workflow"`, a directory that no longer exists. |
| 3 | lib/foundry/improver.ex:432-486 | none | `proposal/3` is a pure extraction. Whitespace-insensitive diff of the old inline body (base lines 418-468) against the new function body shows exactly five changed lines: scope, exclusions and the three `cd workflow &&` prefixes, all intended. `accepted_rev` moved from closure capture to a parameter with the same value; `pad_idx/1` stays private and is still called in-module; call site at line 417 passes the same `{finding, idx}` pairs in the same order. |
| 4 | improver.ex:432, hardening_pm.ex:170,230 | none | `@doc false` public functions for test reach. docs/BOUNDARY-RULES.md's twelve rules cover module and dependency direction (Core/Workflow/kernel/software, DurableStore, Pramāṇa apps); none constrains function visibility. `architecture_boundary_test.exs` passes at the candidate (included in the run below). |
| 5 | all 14 diff paths | none | Every diff path is in the packet scope and the packet scope has no path the diff omits (14 = 14). |
| 6 | ci/validate_fr15aa.exs:306, docs/fr-15a/provisioning-manifest.exs:146 | none | `shasum -a 256 lib/foundry/agent_server.ex` at 7a9b435 = `cc62233d87f17dfa17bae9858e1f1b1d20dacfdadd924beb980a4b48e999cb1f`; both files carry that value. Base digest was `ec7e1ea8…60de`, the value both files carried before. Manifest has the dated reason comment; validate_fr15aa.exs has no comment (the map there is a bare pin table; the criterion's "dated reason comment" is satisfied by the manifest). |
| 7 | test/foundry/{agent_server,improver,hardening_pm}_test.exs | none | Red control run by me (not taken from the report): base tree + candidate improver.ex/hardening_pm.ex with the five strings reverted by sed + the three candidate test files. Result: 5 failures, each on the asserted string (improver scope 1, hardening scope 1, hardening leak-check 1, agent_server developer and reviewer prompt 2); every other test in agent_server_test.exs passed. Developer reported 4; I count 5. |
| 8 | lib/foundry/hardening_pm.ex:215 (pre-existing, out of scope) | low, deferred | `ensure_acceptance_criteria/2` adds the amendment under the atom key `:acceptance_criteria` while every other amendment uses a string key; `Map.merge(ticket, Map.new(amendments))` at line 160 therefore puts an atom key into a string-keyed ticket and the string `"acceptance_criteria"` is never filled. Not introduced or touched by this change; noting because the new test reads `build_amendments/1`. |
| 9 | test/fixtures/python/assignment-v1.json:31, test/fixtures/projections/representative-v1.json:4-5 (out of scope) | info | Still carry `"scope": ["workflow/**"]`. Fixture data for schema/projection tests, not behaviour; not in the packet scope. |

## Acceptance criteria

1. Prompts name `roles/<file>` — agent_server.ex:648,670; asserted for both branches by agent_server_test.exs:181 (parametrised developer/reviewer). Met.
2. Generated scope `lib/foundry/**` in both modules, each asserted; roles/hardening_pm.md has no `foundry/` prefix. Met (see finding 1 for the doc's semantic shift).
3. Fixtures in scope use `lib/...`; assertions unchanged in meaning (scheduler overlap cases keep the same containment relations). Met.
4. Re-pin in both files with dated reason; fr15aa_provisioning_test passes. Met.
5. Format, compile, focused tests: see below. Met.

## Checks run (candidate worktree, TMPDIR=/private/tmp MIX_ENV=test)

- `mix format --check-formatted`: exit 0.
- `mix compile --force --warnings-as-errors`: exit 0 (140 files).
- `mix test` on the 8 touched test files + test/foundry/repair/fr15aa_provisioning_test.exs + test/foundry/architecture_boundary_test.exs: 110 passed, 0 failed.
- Red control (scratchpad copy, described in finding 7): 3 files, 5 failed, all on the new strings.
- `git status --short` in the worktree after the run: empty.
- Not run: full suite, ci/run.exs (per brief).
