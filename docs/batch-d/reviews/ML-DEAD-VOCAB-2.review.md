approved

# ML-DEAD-VOCAB-2 review — candidate ec4b04cd077c79c93077da71dd17f6111bd37313 (base b9d8311)

Reviewer: agent:claude-fable-5-1/review-ML-DEAD-VOCAB-2. Worktree /private/tmp/review-ML-DEAD-VOCAB-2.
(Partial notes written early; the focused-test section is filled in last.)

## Findings, ranked

No blocking finding.

### Minor (non-blocking)

1. `docs/DURABLE-STORE.md:22` — the rewrapped sentence leaves one ~130-char line in a file
   otherwise wrapped at ~90. Cosmetic.
2. `test/foundry/durable_store/fr08a_fr19a_integration_test.exs:233-237` — the four refused
   stores (future/partial/migrated/corrupt) assert only `%{mode: :recovery}`, not the
   reason. The reason for the `migration_v1` case is
   `{:authority_corrupt, "metadata", "keys", :unknown_key}` (reproduced below); pinning it
   would stop a later Authority change from turning a deliberate refusal into an incidental
   one. Suggest, not required.
3. `lib/foundry/durable_store/authority.ex:245` — `:unknown_key` names the table and class
   but not the offending key. Pre-existing shape, unchanged by this ticket.

## Attack results

### 1. Reachability of deleted surface — clean
`git grep` over lib/test/bin/ci/spec/config/rel for `protected_schema_version/0`, `sidecars(`,
`reduce_projection_plan`, `discriminator_kinds`, `legacy_event_append`, `request_effect`,
`legacy_event_types`, `lifecycle_event_types`, `:legacy_record`, `:import_manifest`,
`:import_placeholder`, `:scaffold`, `Gateway.migrate`, `migrate_protected_owned`,
`record_v1_migration`, `migration_v1`, `FOUNDRY_STARTUP_MODE`, `backfill_v1_operations`:
only `@discriminator_kinds` at `transition_plan.ex:29,326` (the attribute is still used by
the private validator; only the public accessor was deleted). The 9 deleted event names:
no hits outside a comment (`kernel/event.ex:99`) and the unrelated `:ref_receipt_recorded`
guard atom. Deleted command names: no store-side hits. Deleted intent names: the
`"prompt"`/`"build"` hits are protected-primitive *operations*
(`protected_primitives.ex:3798`, `protected_primitives_test.exs:86`), a different vocabulary.
No `String.to_atom`/`apply/3` in durable_store, workflow or repair. Kept tables
`import_runs`/`legacy_records` are read raw by `Authority` (`@registry` :37-39, `@unsupported`
:74/:277 requires them empty) — no codec touches them. `mix compile --force
--warnings-as-errors` passing confirms no remaining private function or module attribute
went orphaned (`@protected_schema_version`, `@attempt_closure_schema`, `seed_root_pointers`
are still used by init).

Reopen: `reopen_property_test.exs:35` creates, commits, reopens at random midpoints and at
the end and requires `mode: :ready`; `gateway_test.exs:528-534` reopens after a lifecycle
commit and asserts the same backup reconstruction; the new
`fr08a_fr19a_integration_test.exs:173` commits one domain command, reopens and asserts
`last_durable_sequence: 1`.

### 2. Refusal semantics — clean refusals, no crash
`record_codec.ex:223` (`map["type"] in @command_types`), `:92` (event type), `:124`
(intent operation) are `with` conjuncts whose `else` falls back to `:invalid_command`
/ `:invalid_event` / `:invalid_intent`; shrinking the lists cannot produce a
FunctionClauseError. Reproduced on a fresh store (scratch script, `mix run --no-start`):
`legacy_event_append`, `request_effect`, `steer` → `{:error, :invalid_command}`;
event `ticket_created` → `{:error, :invalid_event}`; intent `prompt` →
`{:error, :invalid_intent}`; gateway `mode: :ready` afterwards. Coverage kept:
`review_corrections_test.exs:15-48` refuses an arbitrary command type, event type and intent
operation with those atoms. The deleted tests were the four migration tests (which only
exercised `Gateway.migrate`) and the legacy/lifecycle disjointness tests (vacuous with one
vocabulary); `gateway_test.exs:490` and `kernel_test.exs:1652` now hold
`Event.types()` and `RecordCodec.event_types()` equal from both sides.

Vocabulary claims checked: `enqueue` is written by `manual_lane/backend.ex:169`;
`plan_launch`/`submit_review`/`settle_nonstart` are lane commands (`backend.ex:106,208,308`)
with kernel `decide/3` clauses (`software/developer.ex:44,76`, `software/review.ex:64,98,129`);
`finalize_cancellation` at `kernel/cancellation.ex:21`. The lane's `"operation"` writes
(`replay.ex:89,120`, `server.ex:313`) are `protected_command` operations, not domain
intents, so `@intent_types ~w(launch check)` cannot affect it.

### 3. FR-08A probe — same guard as before
`gateway.ex:491-521 do_transact`: `prepare_command` (type check) → idempotency lookup →
`normalize_candidate` (bundle keys `record_codec.ex:6`, `:unknown_field` from `keys/3`
:656). `enqueue` has no special routing in the gateway; both the old and new type pass
`prepare_command`, so the probe still reaches the bundle-key guard. Reproduced:
`enqueue` + `claims: [%{forged: true}]` → `{:error, :unknown_field}`; control with the
`claims` key removed → `{:ok, %{"disposition" => "accepted", ...}, :committed}`. So the
refusal is attributable to the smuggled key alone. FR-08A itself is red only from the
pinned hashes (developer's scratch rebind reported green; not re-run here per standing rules).

### 4. `migration_v1` refusal — intended and documented
Only the deleted `record_v1_migration` ever wrote the key. `authority.ex:245` refuses any
key outside the allow-list. Reproduced: fresh store + `INSERT migration_v1='complete'` →
reopen gives `%{mode: :recovery, reason: {:authority_corrupt, "metadata", "keys",
:unknown_key}}`. `docs/DURABLE-STORE.md:75-77` states the contract ("no migration path …
refuses at open"). Consistent with Q1 (archive, never migrate).

### 5. Checks run (worktree, MIX_DEPS_PATH=~/dev/foundry/deps, TMPDIR=/private/tmp)
- `MIX_ENV=test mix compile --force --warnings-as-errors` → exit 0 (54 files).
- `mix format --check-formatted` → exit 0.
- `elixir bin/check_docs.exs` → 0 broken links.
- Scratch reproduction script (above) — all expectations met.
- Focused tests: see below.

### 6. Scope
All 27 changed paths are inside the packet `scope` (durable_store lib+test, workflow
lib+test, repair probe, manual_lane startup_test, test/support, DURABLE-STORE.md, the sweep
row). Nothing outside.

## Focused tests
`TMPDIR=/private/tmp MIX_ENV=test mix test test/foundry/durable_store test/foundry/workflow
test/foundry/manual_lane test/foundry/repair test/foundry/observations_test.exs
test/foundry/schema_reference_test.exs` (serial, detached, nothing else running):
**688/690 passed, 2 failed, 218.8s.** Both failures are
`Foundry.Repair.FR08AProtectedBoundaryTest` ("frozen artifact is deterministic…" and "all six
revision-bound protected capabilities pass…") with `implementation_binding=mismatch` and all
six probes `unavailable|fr08a:loaded_subject_identity_mismatch` — the expected pinned-hash
red awaiting the operator's rebind, not a probe failure. The relational oracle's
`resume_target 1 violated` is informational (`test/support/kernel_harness.ex:134`: nonzero
is expected from the harness's own red controls) and the candidate changes no kernel logic
(only a comment in `kernel/event.ex`).

Worktree left clean: `git diff --exit-code` clean, no tracked changes.

## Verdict
approved — every deleted item is unreachable, refusals stay clean refusals with unchanged
atoms and retained coverage, the FR-08A probe reaches the same bundle-key guard, the
`migration_v1` refusal is the documented fresh-only contract, checks pass, scope holds.
The three minor notes above are optional follow-ups.
