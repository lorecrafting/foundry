approved

# ML-DEAD-ROUTES review — candidate 141428011eb553730f6cc212c2555258c68dafae (base e74fb88)

Reviewer: agent:claude-fable-5-1/review-ML-DEAD-ROUTES, detached worktree /private/tmp/review-ML-DEAD-ROUTES.

## Findings, most severe first

None blocking. Three notes for later tickets and one wording nit.

### N1 (recommendation, later ticket): the legacy tables now have no writer but three live readers

`ledger_generations`, `claims`, `reservations` stay in the v1 schema. Nothing in `lib/` writes them (HEAD grep: no `INSERT INTO ledger_generations|claims|reservations` outside `test/support/legacy_protected_rows.ex`), but they are still read by:

- `lib/foundry/durable_store/authority.ex:210-227,587-625` (open/backup validation) and `:1004-1051` (`read_ledger/2`, the legacy `ledger/` CAS key);
- `lib/foundry/durable_store/protected_primitives.ex:554-567` `authority_mode/1`, which still yields `:legacy` from row counts, and the two `legacy_authority_mode_active` refusals at `gateway.ex:213-215,247-249`;
- `lib/foundry/observations.ex:241,345` (`:legacy` effect-summary branch).

WORKFLOW-CONTRACT.md:178 still documents "the legacy `ledger/` key still reads `ledger_generations`", so retiring the tables, the `:legacy` authority mode, the `ledger/` key and Observations' `:legacy` branch is a contract edit and belongs to a separate ticket with an operator decision. Keeping them here was the right call for this scope; `legacy_protected_rows.ex` is the honest bridge until then.

### N2 (accepted as posed): Observations kept as the in-progress FR-18A slice

REPAIR-PLAN.md:532 marks FR-18A "In progress: bounded protected effect query independently reviewed and integrated". `docs/design/bounded-effect-query-design.md` (status note 2026-09-22) says the `bounded_effect_*` primitives are implemented and names a "public observation layer" (its rule 8, table at :204-210) that "correlates raw protected facts first"; that layer is `Foundry.Observations` + `observations/gateway_source.ex` (only callers: `test/foundry/observations_test.exs`, `test/foundry/durable_store/atomic_bundle_test.exs`). The citation is accurate. The operator question could be sharper: it should ask whether FR-18A's remaining obligations will land a lane command on `Foundry.Observations` or consume `bounded_effect_*` directly, since only the first keeps the module. Not blocking; OBSERVABILITY.md:19-24 says why it stayed and links both records.

### N3 (nit, no change needed): stale option in operational_storage_test

`test/foundry/durable_store/operational_storage_test.exs` still starts several gateways with `protected_capability: capability` (e.g. :207, :236, :403) although no test in the file uses the capability any more. Harmless (the variable is used, so no warning); can go with the next touch of that file.

### N4 (expected, outside scope): FR-08A red for the pins only

`test/foundry/repair/fr08a_protected_boundary_test.exs:10-12` pins `subject_revision`, `subject_tree` and `length(exercised_api) == 10`; the pin list in `lib/foundry/repair/fr08a_protected_boundary.ex` now has 9 entries and `gateway.ex`/`record_codec.ex` changed. The operator's rebind must also change the `== 10` literal to `== 9`. See the test output section for the exact failures.

## Attack items

1. **Route not a safety property.** WORKFLOW-CONTRACT R3 (:87-98) names the "protected verifier/store gateway" as the owner of policy, CAS, ledger, claims, receipts. The lane's only Gateway calls are `Gateway.protected_command` (`manual_lane/server.ex:309`, `replay.ex:85`) and `Gateway.atomic_bundle` (`replay.ex:68`); the only `root_*` writers are `protected_primitives.ex` and `database.ex`. So the R3 role is `protected_command`/`atomic_bundle`/`ProtectedPrimitives`, not the deleted FR-07 `transact_verified`. The old gateway refused the route with `:legacy_protected_route_retired` whenever `authority_mode` was `:root` (base `gateway.ex:209-221`), and `server.ex` seeds a root command on first start, so no lane store could ever take the route. No `docs/REPAIR-PLAN.md` or `docs/design/*` text names `transact_verified`, `ProtectedVerifier`, `protected_facts` or `effect_authorizations` (grep over docs excluding sweep/log/archive: only DURABLE-STORE.md and the R3 role phrase). `docs/design/PROJECT-WORKFLOW-PROFILES.md:277` "protected verifier's role/profile/operation/scope check" is `ProtectedPrimitives`.
2. **`protected` argument always empty on live paths.** Base `gateway.ex:193` (`do_transact(..., %{}, ...)`), and the atomic path passed `%{}` to both `check_expected_revisions/4` and `commit_accepted_bundle` (`:bundle_v2`). The only non-empty sender was `do_verified_transact` (`:534`), i.e. the route. So `required_revisions` merge, `insert_generations/claims/reservations`, the three failpoints and `touched_revisions`' ledger keys were unreachable from `transact`/`atomic_bundle`. Tests that passed non-empty facts (53 base hits across 8 files) asserted either route refusals (deleted with the route) or counts on the three tables (dropped, or moved to the "any integer" group in `sync_fault_test.exs:295-299`).
3. **Seeding helper.** `test/support/legacy_protected_rows.ex` inserts the same rows the route derived for one id (one generation alloc 1/consumed 0, one `claimed` claim on `effect-<id>`, one 1-unit `reserved` reservation), through the same `RecordCodec.encode(:claim|:reservation)` and the same column list as the deleted `insert_generations`. Authority then validates them for real: `validate_protected/4` (claim→reservation, reservation→ledger+claim, funding equality) at open/backup, and `read_ledger/2` on the `ledger/` CAS key. The converted tests still mutate the seeded rows with SQL and assert typed corruption or fencing, so they test Authority, not the fixture. The helper is called only after the effect's command commits (docstring says so; every call site does).
4. **Deleted tests.** (a) authority_test "protected admission rejects improper collections" → `ProtectedVerifier.proper_list?`, gone with the route. (b) authority_test "a zero-available root generation requires no invented reservation" → `allocations_fit/2`, gone. (c) gateway_test "protected facts require the root's unforgeable capability" → route capability check + `:incomplete_protected_read_set`, gone; the surviving `:unauthorized_protected_operation` guard on `protected_command` is covered by `protected_primitives_test.exs:50,734`. (d) review_corrections "unsupported child ledger allocation cannot mint authority" → `RecordCodec.normalize(:candidate_ledger_generation)` parent rule, gone. (e) fr08a_critical_corrections' `{:error, :legacy_protected_route_retired}` assertion → the route's own refusal, gone. Partial: "malformed protected facts and command lookups" kept its command-lookup half. The merged "malformed and unknown-version idempotent results both fence" still exercises both `:malformed_json` and `:unsupported_version`. The failpoint loop keeps `after_inputs..after_intents, after_result`.
5. See "Checks run".
6. See N2.
7. **Scope.** `git diff --name-only e74fb88..HEAD`: 16 paths, all under the packet's `scope` (lib/foundry/durable_store, lib/foundry/repair/fr08a_protected_boundary.ex, test/foundry/durable_store, test/support, docs/DURABLE-STORE.md, docs/OBSERVABILITY.md, docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md).

## Checks run

All in /private/tmp/review-ML-DEAD-ROUTES at 1414280, `MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps TMPDIR=/private/tmp MIX_ENV=test`:

- `mix compile --warnings-as-errors`: exit 0, no warnings. Test compile also emitted no compiler warnings (the single `warning:` line in the log is the lane CLI's runtime "operator log not written ... :eisdir" from a manual_lane refusal test).
- `mix test test/foundry/durable_store test/foundry/manual_lane test/foundry/repair test/foundry/observations_test.exs`: **381/383 passed, 2 failures, 132.8 s**. Both failures are `test/foundry/repair/fr08a_protected_boundary_test.exs` (:6 `implementation_binding == "verified:..."` got `"mismatch:..."`; :35 frozen report differs from `docs/fr-08/fr08a-protected-report.txt` by the removed `protected_verifier.ex` source line and the unavailable probes). That is the expected pin red; the run never reached :12's `== 10`, which the rebind will also have to change to `== 9`. `reopen_property_test` and the sync/crash fixtures in durable_store passed within this run.
- `elixir bin/check_docs.exs`: 0 broken links (tracked files only).
- `git diff --name-only e74fb88..HEAD`: 16 paths, all inside the packet `scope`.
- HEAD grep for `transact_verified|ProtectedVerifier|candidate_ledger|after_generations|after_claims|after_reservations|protected_facts|effect_authorizations|legacy_protected_route_retired|invalid_protected_facts|incomplete_effect_authorization|insufficient_ledger_allocation|unsupported_child_ledger_generation|incomplete_protected_read_set|invalid_required_revisions|invalid_effect_authorization|invalid_protected_fields` over lib/ test/ bin/ ci/ config/ and live docs: only the retirement note in `docs/DURABLE-STORE.md:34`, the helper's docstring and a test comment; no code reference.
- Base grep (`git grep ... e74fb88 -- lib/`): every lib reference to the deleted names lived in `gateway.ex`, `protected_verifier.ex`, `record_codec.ex` or the FR-08A pin list; 53 test references across the 8 rewritten test/support files, none elsewhere.

Not run: ci/run.exs, the full suite, any rebind (per standing rules).
