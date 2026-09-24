approved
# Review ML-RENAME-BIN-ENV, candidate c73b6ea (base 9c7fe01)

Reviewer agent:claude-fable-5-1/review-ML-RENAME-BIN-ENV, detached worktree /private/tmp/review-ML-RENAME-BIN-ENV. Independent of the developer (agent:claude-opus-5-5/dev-ML-RENAME-BIN-ENV). No gate rerun; no daemon started, stopped or built.

## Verdict

Approved. One commit, 51 files, 168/168 lines. Hard rename with no aliases (Q7), dated records rewritten (Q6), every changed path inside the packet scope, FR-08A pinned modules (protected_primitives.ex, gateway.ex) untouched. No blockers, no corrections; three informational notes below.

## Findings (ranked)

1. Info, no action: two rewritten measurement rows now cite a grep they did not historically run. docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md:33 (`git grep -h -o -E 'FOUNDRY_[A-Z_]+'` with counts 36/26/25/15/9 that were measured with the old prefix and do not reproduce today) and docs/batch-d/reviews/ML-RENAME-NS.review-1.md:23 ("the live set (`FOUNDRY_RELEASE` 25 ...) is untouched", which described the old names being left alone by ML-RENAME-NS). This is the direct consequence of Q6 (rewrite dated records) and is consistent across the commit; recording it so the counts are not re-cited as current.
2. Info, out of scope: `FOUNDRY_STARTUP_MODE` has no reader. lib/foundry/application.ex:44 derives the mode from `FOUNDRY_MANUAL_LANE` alone; the only occurrences are test/foundry/manual_lane/startup_test.exs:14,42, which set it to prove it is ignored. Renaming the phantom is harmless and keeps the test honest; deleting it belongs to a later cleanup.
3. Info, next ticket: lowercase Pramāṇa strings remain by design — rel/overlays/env.sh:20 `# export RELEASE_NODE=pramana_workflow` (commented sample), config/config.exs:6 `pramana-foundry-test-operator`, and `bin/pramana-*` retired-script names in 5 archive docs. All match the accepted carve-out (ML-RENAME-DOMAIN-TAGS).

## Attack results

1. Completeness. `git grep -n 'PRAMANA_' -- .` -> 0. `git grep -n 'PRAMANA' | grep -v PRAMANA_` -> 0. `git grep -nE 'bin/pramana([^-]|$)'` -> 0 (wrapper refs gone; `bin/pramana-` retired names remain, as accepted). Split-form grep (`"PRAMANA" <>`, `_RUNTIME_ROOT"`, `STARTUP_MODE`, `RELEASE"`) over lib test config rel ci bin .github -> every hit is a whole `FOUNDRY_*` literal; no interpolated or concatenated old name. `.github/workflows/foundry-ci.yml`, rel/overlays/env.sh, rel/vm.args, config/*.exs, mix.exs, .gitignore: no uppercase PRAMANA. Scope: `git show --name-only c73b6ea` filtered against the packet scope list -> 0 paths outside.
2. Runtime wiring, traced set -> reader:
   - `FOUNDRY_RELEASE`: set bin/foundry-lane:16 (default) and exported :23-25; read bin/foundry:32-38 (override) and bin/foundry-lane:28,41,43,45,57,61; tests rpc_wrapper_test.exs:145,194,224,242,260,270 and startup_test.exs:85.
   - `FOUNDRY_RUNTIME_ROOT` / `_FRESH`: exported bin/foundry-lane:18,23; read lib/foundry/runtime_root.ex:15-16 -> :44-45 (`System.get_env(@override)`, `System.get_env(@fresh)`); set/unset lib/foundry/ci.ex:76-77; tests runtime_root_test.exs, ci_test.exs:53.
   - `FOUNDRY_OPERATOR_RUNTIME_ROOT`: read config/config.exs:4; set lib/foundry/ci.ex:75.
   - `FOUNDRY_STARTUP_MODE`: no reader (finding 2).
   - No var is set under one name and read under the other.
   Exercised without a daemon (`env -i HOME PATH ...`): `bin/foundry-lane env` prints the 7 exports with the new names; `FOUNDRY_RELEASE=/nope/rel FOUNDRY_RUNTIME_ROOT=/nope/root bin/foundry-lane env` echoes both overrides; `PRAMANA_RELEASE=/old/rel bin/foundry-lane env` still prints the default (old name inert); `FOUNDRY_RELEASE=/nope/rel bin/foundry ticket list` -> "Error: FOUNDRY_RELEASE is not executable: /nope/rel", rc 69; same via `bin/foundry lane status` (lane env path) rc 69; `FOUNDRY_LANE_BUILD=/nope/build bin/foundry lane status` -> error names `/nope/build/rel/foundry/bin/foundry`, rc 69, unchanged with `PRAMANA_RELEASE` also set; `bin/foundry-lane status` with no release -> "no lane release at ...; run: bin/foundry-lane build", rc 69.
3. Aliases/collisions. No `${PRAMANA_...:-}` or `System.get_env("PRAMANA...")` fallback anywhere (grep above). Live `FOUNDRY_*` inventory over lib test config rel ci bin .github: RELEASE 25, RUNTIME_ROOT 18, MANUAL_LANE 13, DIR 9, RUNTIME_ROOT_FRESH 7, MANUAL_LANE_POLICY 7, MANUAL_LANE_REPO 5, LANE_BUILD 5, MANUAL_LANE_STORE 4, REOPEN_STATS/SEED/RUNS 3 each, STARTUP_MODE 2, OPERATOR_RUNTIME_ROOT 2, REOPEN_LIVE 1. The five new names are disjoint from the pre-existing ten.
4. Tautologies. `git grep -nE 'FOUNDRY_FOUNDRY|bin/foundry` (to|->|→) `bin/foundry|foundry to foundry|FOUNDRY_\w+ (to|->|→) `?FOUNDRY_'` -> 0. Docs describing the rename say "Pramāṇa-era" for the old side (REPAIR-PLAN Q7 row, CLEAN-ROOM-SWEEP §B, ML-RENAME-NS.review-1 finding 3); read each in the diff, none is circular.
5. Checks (TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps):
   - `mix compile --force --warnings-as-errors` -> rc 0, 0 warning lines.
   - `mix format --check-formatted` -> ok.
   - `mix test test/foundry/cli test/foundry/manual_lane test/foundry/rpc_wrapper_test.exs test/foundry/runtime_root_test.exs test/foundry/ci_test.exs test/foundry/boundary_test.exs test/foundry/architecture_boundary_test.exs test/foundry/repair/fr08a_protected_boundary_test.exs` -> rc 0, 124 passed, 0 failures (fr08a pins for protected_primitives.ex and gateway.ex unchanged, so no rebind needed; the developer's "no FR-08A pinned file changed" claim holds).
   - `elixir bin/check_docs.exs` -> 0 broken link(s).
6. Not run: ci/run.exs, full suite, any lane build/start/stop (per brief).

## Limitations

Docs in docs/archive were checked by grep and by reading the diff hunks, not each file in full. The lane daemon and live store were not touched, so "old store opens under the renamed wrapper" remains the integration-time check named in ML-RENAME-NS review.
