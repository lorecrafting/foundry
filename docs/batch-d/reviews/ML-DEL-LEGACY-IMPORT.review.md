approved

# ML-DEL-LEGACY-IMPORT review — candidate e23075e on base 5fb7603
Reviewer: agent:claude-fable-5-1/review-ML-DEL-LEGACY-IMPORT (independent; did not write it).
Worktree: /private/tmp/review-ML-DEL-LEGACY-IMPORT. Deps via MIX_DEPS_PATH from the main checkout.

## Checks run
- `mix compile --force --warnings-as-errors`: clean.
- `mix test test/foundry/durable_store`: 285 passed (includes reopen_property_test "every committed state reopens :ready", cancel/ledger restart probes, live_refusal_probe).
- `mix test test/foundry/workflow test/foundry/manual_lane test/foundry/architecture_boundary`: 369 passed.
- `mix test test/foundry/repair`: 14/17; the 3 failures are all fr08a_protected_boundary_test with `fr08a:loaded_subject_identity_mismatch` and the frozen-artifact diff (7 -> 6 capabilities, legacy_import.ex line gone). Expected; lead rebinds. fr08_handoff_gate_test passes at 6.
- Red control: removed `import_runs` from `@unsupported` -> authority_test:453 "every unsupported authority table fences startup" fails (store reopens :ready instead of :recovery). Restored by exact string; `git diff` empty.
- `elixir bin/check_docs.exs`: 0 broken links.
- Live sha256 vs pinned: RED exactly authority.ex, kernel.ex, fr08_handoff_gate.ex; the other 7 pins match. legacy_import.ex correctly dropped from the pin list; schema/atomic_file/legacy_line/h0 were never pinned.

## Claims
1. authority.ex: diff is removal-only apart from the `@unsupported` line and the `validate_content/1` arity. Removed: `{:import, digest}` read (no callers in lib/test), `validate_imports`, `validate_import_group`, `reduce_legacy_row`, `finish_legacy_summary`, the `legacy_records` skip in `validation_rows`, the `imports` view key (no readers). Every other with-clause in `read/2` and `validate_content` is unchanged. No live writer of `import_runs`/`legacy_records` remains in lib (only the CREATE TABLE in database.ex and the registry). Fencing on a leftover row is the right fail-closed behaviour for fresh stores (same path as receipts/leases). Note: `legacy_records` in `@unsupported` is effectively shadowed (FK to import_runs is checked first by validate_foreign_keys, and import_runs precedes it in the list) — harmless, keep for symmetry.
2. Kernel: only gateway.ex:1494 calls `normalize_bundle/1`; `validate_bundle/1` and the `decide`/`apply` callbacks had no callers or implementers. Minimal and correct.
3. fr08_handoff_gate.ex: only the capability tuple and the type union entry are removed; the gate's counting/ready logic is untouched and fr08_handoff_gate_test passes at 6. The out-of-scope edit is unavoidable (the probe's subject is deleted) and is the smallest possible; acceptable given the lead rebinds anyway.
4. CI: `git grep 'pramana/' -- test ci lib bin .github` is empty; base tree shows the only user was h0_accepted_fr07_boundary_test. ci.ex uses only rev-parse/status/ls-files; bin/rebind_fr08a.exs rev-parse only. Shallow clone is safe.
5. Knowledge section: verified cli.ex:380 plain `File.write` of the packet, log.ex:184 `File.write(..., [:append])` with no sync, ci.ex:675 rename without fsync. The coverage table's "Now" pointers exist. Accurate.
6. Deferred `:legacy_record`/`:import_manifest` codecs in record_codec.ex: fine for ML-DEAD-VOCAB; record_codec.ex is pinned and removing them now would widen the Core diff for no behaviour change.

## Non-blocking notes
- docs/fr-08/fr08a-protected-report.txt still lists 7 capabilities and legacy_import.ex; the rebind regenerates it.
- docs/AUDIT-2026-09-12.md link now points at a pinned GitHub blob URL for schema.ex at 5fb7603; fine as history.
