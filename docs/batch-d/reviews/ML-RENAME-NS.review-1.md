correction

# Review: ML-RENAME-NS (candidate ff0b5d5 on base b30d0a2)
Reviewer: agent:claude-fable-5-1/review-ML-RENAME-NS. Worktree /private/tmp/review-ML-RENAME-NS (restored clean after the scratch rebind).

Method: `git archive` of base, apply the same mechanical rewrite (dir moves + perl `PRAMANA_FOUNDRY_RUNTIME_DIR->FOUNDRY_RUNTIME_DIR`, `PramanaFoundry->Foundry`, `pramana_foundry->foundry`), `diff -r` against the candidate. Residual = 203 lines: the 62 AUDIT-2026-09-12 permalinks (exception a), 3 formatter reflows (fr08a_protected_boundary.ex:46-51, architecture_boundary_test.exs:67, r4_no_direct_apply_test.exs:88-91), and 1 env-label line (finding 3). So the rewrite is exactly what it claims, and every non-mechanical edit is accounted for.

## Findings (by severity)

### 1. Correction: the rewrite turned the three descriptions of this rename into tautologies
The regex could not know that a sentence describing the rename must keep its "from" side. Three places now say the rename is from Foundry to Foundry:

- docs/REPAIR-PLAN.md:539 (live ticket table, FR-23b row): "rename the `Foundry` namespace to `Foundry`".
- docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md:234 (this ticket's own definition): "**ML-RENAME-NS** (`Foundry`→`Foundry`, `:foundry`→`:foundry`, `lib/foundry/`→`lib/foundry/`, `test/foundry/`→`test/foundry/` ...)".
- docs/fr-23/FR-23-SPLIT-PROPOSAL-2026-09-22.md:164-165: "`:foundry` → `:foundry`, modules `Foundry.*` → `Foundry.*`, `lib/foundry/` and `test/foundry/` → `lib/foundry/` and `test/foundry/`."

Ask: reword the three so the "from" side is named without reintroducing the token the acceptance grep forbids, e.g. "rename the Pramāṇa-era `Pramana`-prefixed namespace, app and directories to `Foundry`, `:foundry`, `lib/foundry/`, `test/foundry/`" (or the operator grants an exception (c) for these three lines to keep the literal old names, which is the more honest record). Either way the REPAIR-PLAN row must read correctly; it is the live plan, not a dated record.

### 2. Gap: acceptance criterion 4 ("reports whether a renamed build opens a copy of the current lane store as ready") is not reported in any artifact I could see
Neither the commit message nor the packet carries the report. Code-path reading in the candidate: no module or app name is persisted. `:erlang.term_to_binary` occurs only at lib/foundry/durable_store/authority.ex:1224, gateway.ex:2445, maintenance.ex:52, all evidence digests over reconstructed row maps that are reported, never compared with stored bytes; `PathIdentity` binds by device/inode/basename (path_identity.ex:182-191); the `pramana-foundry-*` digest domain tags and `repository_id: "pramana-foundry"` are untouched (fr08a_protected_boundary.ex:604). So a renamed build should open an old store unchanged. That is inference from code, not a run: the developer (or operator, at integration) should state the result of `bin/pramana lane status` against a copy of the store. I did not touch the live store.

### 3. Info: docs/archive/fr-01/review-v1.md:54 `PRAMANA_FOUNDRY_*` -> `FOUNDRY_*`
Same family as accepted exception (b). No live env var starts with `PRAMANA_FOUNDRY_`; the live set (`PRAMANA_RELEASE` 25, `PRAMANA_RUNTIME_ROOT` 18, `PRAMANA_RUNTIME_ROOT_FRESH` 7, `PRAMANA_OPERATOR_RUNTIME_ROOT` 2, `PRAMANA_STARTUP_MODE` 2 occurrences in lib/bin/test/config/rel) is untouched. Accepted.

### 4. Info: Q6 side effects in docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md that now read oddly but are covered by "rewrite everything"
- Measurement row: `FOUNDRY_RUNTIME_DIR 4` listed under the `PRAMANA_*` grep column (:~150).
- Q11 probe: `pgrep -fl 'sname foundry'` where the legacy daemon's node was the old name (:~262).
- "| `mix.exs` | app `:foundry`, release `foundry`, escript `Foundry.CLI` | FR-23b |" reads as already done.
No action unless the operator wants the measurement rows footnoted.

## Checks that passed
- Scope: all 314 changed paths inside the packet scope list (0 outside).
- Completeness: `git grep -n -i 'pramana_foundry\|PramanaFoundry'` -> 62 lines, all in docs/archive/AUDIT-2026-09-12.md inside `github.com/lorecrafting/foundry/blob/<40-hex>/` permalinks (exception a); 0 lines elsewhere. No `Pramana.Foundry`, `Elixir.Pramana*`, or `PRAMANA_FOUNDRY` remains. `Module.concat`/`String.to_atom` sites (architecture_boundary_test.exs:233, non_launch_test.exs:131, test/support/ast_modules.ex:29,54, kernel_search.ex:271, backend.ex:518) build from source text or reasons, not from a hard-coded old prefix.
- Pramāṇa-repo references: 25 files carry `github.com/lorecrafting/pramana`; 0 diff lines touch them. No pre-existing `Foundry` module/alias in base to collide with. No doubled words (`foundry foundry`, `app app`, `the the`: 0).
- Wiring: mix.exs `app: :foundry`, `releases: [foundry: ...]`, escript `Foundry.ManualLane.CLI`; `.gitignore /foundry`; ci.ex artifact `artifacts/foundry`, tracked-escript check `ls-files foundry`, `Mix.Project.in_project(:foundry, ...)`, runner sha over `lib/foundry/ci.ex`; bin/pramana `RELEASE_BIN=.../_build/prod/rel/foundry/bin/foundry` and `Foundry.CLI.RPC.run(...)`; bin/foundry-lane `PRAMANA_RELEASE=$FOUNDRY_LANE_BUILD/rel/foundry/bin/foundry`; config `config :foundry, runtime_root:`; every `Application.get_env/fetch_env/put_env` reader uses `:foundry` (application.ex:50, server.ex:53-54, runtime_root.ex `@app :foundry`, runtime_root_test). rel/ overlays carry no app name (env.sh:19 `pramana_workflow` comment is pre-existing and out of scope). No `_build/test/lib/<app>` assumption in lib/test.
- FR-08A: red on the candidate as expected (`mismatch:source-sha256+beam-md5/v1`, frozen report differs); scratch rebind (`bin/rebind_fr08a.exs` + report regeneration in a fresh VM) -> 4/4 passed, `ready=true`. Rebind files restored from ff0b5d5 afterwards; worktree clean.
- Dated records read correctly (DOGFOOD-READINESS-2026-09-23, THIN-LANE-DESIGN-2026-09-23, FR-23-SPLIT-PROPOSAL-2026-09-22 apart from :164-165, O0-AUTHORITY-INVENTORY-2026-09-22, RELOCATION-RULES-2026-09-23, audit-2026-09-12/{inventory.json,probes.exs}); README/AGENTS.md: 2 lines each, correct.

## Commands run (worktree /private/tmp/review-ML-RENAME-NS, TMPDIR=/private/tmp, MIX_ENV=test, MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps)
- `git diff --stat b30d0a2 ff0b5d5`: 314 files, +1986/-1992; `git diff -M --name-status`: 54 lib + 55 test renames.
- `mix compile --force --warnings-as-errors`: 54 files, 0 warnings, exit 0.
- `mix format --check-formatted`: exit 0. `elixir bin/check_docs.exs`: 0 broken links.
- `mix test` over 19 files (manual_lane/{cli,server,backend,startup,non_launch,restart_drill}, cli/rpc, rpc_wrapper, durable_store/{gateway,authority,path_identity,record_codec}, ci, boundary, architecture_boundary, runtime_root, repair/{fr08a_protected_boundary,fr08_handoff_gate}, workflow/r4_no_direct_apply): 213/216. Failures: 2 x FR-08A (expected until rebind), 1 x authority_test.exs:743 `File.mkdir!` on pre-existing /private/tmp/fr07-authority-5506 (stale dir from a 07:02 run; `unique_integer` collision, the known suite gotcha). `mix test --failed`: authority test passed, FR-08A 2 still red as expected.
- After scratch rebind: `mix test test/foundry/repair/fr08a_protected_boundary_test.exs`: 4 passed.
- Not run: ci/run.exs, full suite, anything against the live lane store.
