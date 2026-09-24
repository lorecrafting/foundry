approved

# ML-DEL-LEAVES review — candidate 61b2c3e on base db4334c

Reviewer: agent:claude-fable-5-1/review-ML-DEL-LEAVES (independent; did not author the change).
Worktree: /private/tmp/review-ML-DEL-LEAVES (detached at 61b2c3e). 3 commits, 46 files, +48/-8058.

## Findings

1. **info** — `test/pramana_foundry/relocation_containment_test.exs` deleted outside the packet scope
   (scope has `relocation_test.exs` and `relocation/**`, not this file). Acceptable, no correction:
   the file's only subject is `PramanaFoundry.Relocation` (alias line 4; both tests assert
   `{:error, {:relocation_disabled, :fr19b_required}}` from `execute/resume/rollback`). Once
   `relocation.ex` is deleted it cannot compile, so keeping it would have broken
   `--warnings-as-errors`/the suite. Its two rules are recorded in
   `docs/archive/RELOCATION-RULES-2026-09-23.md:12` (first table row). Suggest the integrator
   note the scope overrun in the ticket record; no new ticket needed.
2. **info** — `test/support/fr19a_maintenance_crash_fixture.exs` correctly kept: only consumer is
   `test/pramana_foundry/durable_store/operational_storage_test.exs:439` (an in-gate test).
   It is not sync-EIO code despite matching the `test/support/fr19a_*` scope glob.
3. **info** — check_docs: candidate reports exactly 7 broken links, base reports 0. The 7 are:
   `docs/AUDIT-2026-09-12.md` x3 (`relocation.ex#L159`, `relocation/manifest.ex`,
   `relocation/worktree.ex#L211`), `docs/BIN-SCRIPT-HEALTH-2026-09-22.md`,
   `docs/DOC-RETIREMENT-INVENTORY-2026-09-22.md`, `docs/README.md:53`, `docs/STRATEGY.md`
   (all four `ASSESSOR.md` → now `archive/ASSESSOR.md`). Developer's list is complete; nothing
   else broke. All 7 files are outside the packet scope (another ticket / operator at integration).
4. **low, out of scope, for the integrator** — stale live prose (not links, so check_docs is
   silent): `README.md:16` lists "relocation" as a component and `README.md:136` shows
   `relocation/ — historical move code; mutation disabled pending FR-19B` in the tree;
   `docs/DURABLE-STORE.md:186-189` still says relocation entry points return
   `:relocation_disabled` and tests are "preserved but skipped until FR-19B". Both files are
   outside scope; report only.
5. **none** — `lib/pramana_foundry/ci.ex`, `cli.ex`, `application.ex`, `docs/README.md`
   untouched, per acceptance criterion 4. No changes to those files are needed for compile or
   the surviving tests; only the doc-link fixes in finding 3.

## Checks

- `git grep -n -iE 'assessor|relocation|fr19a_sync|sync_eio|sync-eio|LocalExclude' -- ':!docs/**' ':!*.md'`
  → 0 hits (exit 1). No live lib/test/ci/config/mix/workflow reference to any deleted module.
  Same grep over `mix.exs test/test_helper.exs ci/run.exs lib/pramana_foundry/ci.ex config/ .github/`
  → 0 hits.
- `git diff --name-status -M db4334c HEAD` → 46 paths; 45 inside scope globs, 1 outside
  (finding 1). `docs/ASSESSOR.md` → `docs/archive/ASSESSOR.md` is a 95% rename with a retirement
  banner and three `../` link fixes; `docs/fr-19a/linux-sync-eio-plan.md` gains a banner and
  de-links the deleted workflow.
- `mix compile --force --warnings-as-errors` (MIX_ENV=test) → exit 0, 119 files.
- `mix test test/pramana_foundry/durable_store/{sync_fault_test,operational_storage_test,fr08a_fr19a_integration_test}.exs`
  → 24 passed, 0 failures, exit 0 (100.2 s). All three files present and unmodified by the diff.
- `elixir bin/check_docs.exs` → candidate 7 broken, base (main checkout, db4334c) 0 broken.
- Workflow gating confirmed: `fr19a-sync-eio.yml` pushes only on `repair/fr19a-correction`;
  `git ls-remote --heads origin | grep -c fr19a` → 0, so it never ran on this remote (matches
  sweep Q7 and the new banner).
- Knowledge spot-check of `docs/archive/RELOCATION-RULES-2026-09-23.md` against
  `git show db4334c:<test>`:
  - `relocation/worktree_test.exs` — test names at :52 (`:cannot_move_original_checkout`), :60
    (`:cannot_move_root_chat_directory`), :70 (`{:destination_collision, _}`), :82 (git worktree
    move, original intact), :113 (move + rollback of plain dir) all match rows 4, 5, 10.
  - `relocation/digest_test.exs` — :15 lowercase sha256, :21 skips `.git`, :57 missing +
    mismatches reported: matches row 6.
  - `relocation/path_map_test.exs` — :32 longest prefix, :50 reverse_resolve, :60 JSON
    persistence, :79 chain: matches row 8.
  - `relocation_containment_test.exs` — both test names quoted verbatim in row 1.
  - `relocation_test.exs:54` plan excludes original checkout (row 4); :74 and
    `crash_recovery_test.exs:8` are skip-tagged "until FR-19B" as the archive states.
  - "Where the deleted code fell short" reproduces `docs/AUDIT-2026-09-12.md:487` F21 faithfully
    (live handles, invented headroom, empty digest map, cross-device removal before verify,
    journal schema/`String.to_atom`, rollback collisions, cross-device untested).
- Not run: `ci/run.exs`, full suite (per reviewer instructions).
