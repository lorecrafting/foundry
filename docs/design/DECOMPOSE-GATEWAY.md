# Design: decompose `gateway.ex`

Ticket ML-DECOMPOSE-GATEWAY-DESIGN, 2026-09-24, base `e74fb88`. This is protected Core, so
the design is reviewed before anyone implements it ([agent brief](../AGENT-BRIEF.md#reviews)).
Implementation is ML-DECOMPOSE-GATEWAY (batch C2). Subject:
[`gateway.ex`](../../lib/foundry/durable_store/gateway.ex), 2,456 lines. All line numbers
below are at `e74fb88`.

## 1. Call graph at `e74fb88`

**External callers (lib).** Only ManualLane, FR-08A, Observations and one ProtectedPrimitives
back-edge call Gateway:

| Caller | Gateway functions used |
|---|---|
| `manual_lane/server.ex` | `initialize/2`, `start_link/1`, `status/1`, `protected_command/4`, `protected_query/3` |
| `manual_lane/replay.ex` | `atomic_bundle/4`, `protected_command/4`, `protected_query/3` |
| `manual_lane/cli.ex` | `status/1` (its `:gateway_recovery` refusal is derived from `mode: :recovery`) |
| `repair/fr08a_protected_boundary.ex` | `initialize`, `start_link`, `status`, `transact`, `protected_command`, `protected_query`, `protected_snapshot` |
| `observations/gateway_source.ex` | `protected_query/3`, `protected_snapshot/2` (module may be deleted by ML-DEAD-ROUTES) |
| `protected_primitives.ex:6048` | `atomic_domain_request/1` (`@doc false`; a Core→Core back-edge) |
| `workflow/kernel/plan.ex:34` | comment only, naming `Gateway.domain_read_namespaces/0` |

**Tests.** 35 files call Gateway. Call counts: `status` 101, `transact` 64, `initialize` 58,
`protected_query` 53, `backup` 52, `atomic_bundle` 49, `transact_verified` 38 (8 files),
`protected_command` 28, `counts` 21, `command` 16, `operational_health` 14, `start_link` 13,
`checkpoint` 7, `recent_events` 6, `protected_snapshot` 5, `domain_read_namespaces` 1. Tests
also depend on these internals:

- **State shape.** `:sys.get_state/1` reads `conn`, `owner`, `mode`, `reason`,
  `protected_capability`, `writer_epoch`, `capacity_probe` and `operational_health_requests`,
  in both the ready and the recovery state (`fr08a_fr19a_integration_test.exs:29-63`,
  `operational_storage_test.exs`).
- **Source text.** `test/support/fr08a_identity_negative_fixture.exs` recompiles
  `Gateway.module_info(:compile)[:source]` after splicing text in at the exact line
  `  def command(server, command_id), do: GenServer.call(server, {:command, command_id})`.

**Internal structure.** Every public function is a `GenServer.call` into one process. Every
`handle_call` except `:status` (127-129, which answers in both modes) has a
`%{mode: :recovery}` clause, and the ready clauses end in `transition_after_result/2`.

| Region | Lines | Contents | Calls into |
|---|---|---|---|
| A. API and GenServer | 1-489 | `initialize`, API wrappers, `init`, `terminate`, 14 `handle_call`, 3 `handle_info`, `find_health_request`, `open` | Owner, PathIdentity, Database, ProtectedPrimitives (`authority_mode`, `execute`, `query`, `snapshot`), B, C, D |
| B. v1 domain commit | 491-551, 1471-2054, 2069-2075, 2450-2455 | `do_transact`, `do_verified_transact`, `normalize_candidate`, `prepare_command`, `commit_bundle`, `commit_accepted_bundle`, `commit_rejected_command`, `insert_*`, `existing`, `fetch_command`, `current_seq`, `check_expected_revisions` and its helpers, `validate_actor`, `reduce_insert`, `inject`, `semantic_rejection?`, `get` | Kernel, TransitionPlan (`slot_event_types/0`, 1477), RecordCodec, Encoding, Authority, Database, ProtectedVerifier, `ProtectedPrimitives.root_command_id_exists?` |
| C. v2 atomic bundle | 553-1469 | `do_atomic_bundle` through `nonstarts_bound?`, plus the domain-read checks and `@domain_read_namespaces` (1407-1469) | B (9 functions, below), TransitionPlan, ProtectedPrimitives (8 functions), RecordCodec, Encoding, Authority, Database |
| D. Operations | 2098-2433 | `read_operational_health`, `add_physical_capacity`, `query_recent_events`, `checkpoint_database`, maintenance fault helpers, capacity-probe controller, `file_size`, backup and `verify_backup`, `sync_*`, `publication_reconstruction` | Database, Authority, PathIdentity, Encoding |
| A (kept) | 2056-2067, 2077-2096, 2435-2448 | `transition_after_result`, `maybe_limit_pages`, `recovery_state` | — |

C uses these B functions: `prepare_command/2`, `normalize_candidate/1`,
`check_expected_revisions/4`, `commit_accepted_bundle/9`, `commit_rejected_command/7`,
`inject/2`, `validate_actor/1`, `projection_key/2` and `encode_key/1`. B uses nothing from C.
D uses nothing from B or C. So the regions already form a DAG, A → C → B and A → D; no
function has to be rewritten to split them.

## 2. Target modules

| Module | Takes | Public API (`@doc false` unless noted) | Size |
|---|---|---|---|
| `Gateway` (kept: facade and GenServer) | Region A as listed | Unchanged public API; `domain_read_namespaces/0` and `atomic_domain_request/1` become `defdelegate` to `AtomicBundle` | ≈540 |
| `DurableStore.DomainCommit` (new) | Region B | `do_transact/6`, `do_verified_transact/6`, `fetch_command/2` for Gateway; the 9 functions above for AtomicBundle | ≈660 |
| `DurableStore.AtomicBundle` (new) | Region C | `do_atomic_bundle/5`, `atomic_domain_request/1`, `domain_read_namespaces/0` | ≈920 |
| `DurableStore.Maintenance` (existing, 56 lines) | Region D | `read_operational_health/1`, `add_physical_capacity/2`, `normalize_capacity_result/1`, `capacity_probe_controller/5`, `query_recent_events/2`, `checkpoint_database/2`, `backup_database/3`, plus the existing `verify/2` | ≈390 |

Dependencies: Gateway → {AtomicBundle, DomainCommit, Maintenance}, AtomicBundle →
DomainCommit, and all three → the existing leaves (Database, Authority, RecordCodec,
Encoding, PathIdentity, Kernel, TransitionPlan, ProtectedPrimitives). None of the new
modules calls Gateway. The one cycle is ProtectedPrimitives → `atomic_domain_request`, which
already exists today as ProtectedPrimitives ↔ Gateway. See seam S2 in §6.

**Why these seams, and only these.**

- **Gateway keeps** everything that touches process state: owner acquire and release,
  `PathIdentity` revalidation around open, the capability check, `authority_mode` routing,
  recovery clauses and `transition_after_result`. Fencing therefore stays in one file you can
  read top to bottom. The GenServer state map never leaves Gateway. The one exception is
  that `read_operational_health/1` takes the state as it does today; narrowing it to
  `(conn, path)` is optional tidy-up T4.
- **DomainCommit and AtomicBundle** are the two write protocols, v1 domain and v2 bundle.
  Each has its own digest tag, idempotency table and result shape. The v2 protocol is built
  on the v1 protocol: the domain operation of a bundle commits through
  `commit_accepted_bundle` inside the bundle's transaction. The seam is that layering and
  nothing else.
- **AtomicBundle is not split further.** Plan resolution (1266-1469) could move out, but
  that would part the envelope normalizer from the checks it depends on. The repair plan's
  rule is to split by family, not by kind, and to ask whether one read holds everything
  needed to change a function safely ([repair plan](../REPAIR-PLAN.md)).
- **The operational code goes into Maintenance, not a new module.** It is the online half
  of what `Maintenance.verify/2` does offline. The two already share bodies:
  `Maintenance.replay_evidence/1` is identical to `publication_reconstruction/1` (2425), and
  `last_sequence/1` runs the same SQL as `current_seq/1`. The alternative home, `Capacity`,
  holds only the `df` probe, and that probe is not pinned (see §3, pins).
- **Rejected options.** An `Inserts` module would hold only rows, and `commit_accepted_bundle`
  is the one caller of every insert, so it would add a seam with a single user. A `Helpers`
  module would hold `get`, `inject` and `validate_actor`, which would scatter the fault-point
  vocabulary.

## 3. Invariants that must not change

| Invariant | Enforced today | How the split keeps it |
|---|---|---|
| Public API: the 16 functions and arities in §1, return shapes, `:infinity` timeouts on `backup`, `operational_health` and `checkpoint` | `gateway.ex:27-96` | Lines 27-96 stay in `gateway.ex` byte-identical |
| `Gateway` is the source of `module_info(:compile)[:source]`, and the negative-fixture needle line exists there | `gateway.ex:68`, `fr08a_identity_negative_fixture.exs:6` | `def command` stays in `gateway.ex` |
| State keys, ready and recovery | `open/2` 452-471, `recovery_state/2` 2435-2448 | Both stay in Gateway |
| Digest domains: `"foundry-command-v1"` (canonical, 1499), `"foundry-atomic-bundle-v2"` (`semantic_digest`, 592); derived IDs `"input:" <> id` (1675, 1685) and `"atomic-v2/#{digest}/#{ordinal}"` (944); `owner_kind` `'domain_v1'` (1664) and `'bundle_v2'` (1180) | B and C | Pure move; each literal is grep-counted before and after |
| Transactions: exactly three `Database.transaction` sites (666, 1081, 1510), none nested. `commit_accepted_bundle` and `commit_rejected_command` open none and run inside their caller's transaction. A rejected bundle persists in a second transaction after the first rolls back (1066-1120). The reply comes only after the checked `COMMIT` | B and C | Pure move; grep count stays 3 |
| Owner and recovery fencing: `Owner.acquire` (31, 441) and release (38, 122, 475, 481); `PathIdentity.revalidate` around `Database.open` (443-445); `recovery_evidence` is passed through opts to `Owner.acquire`; the `.owner.unclean` marker lives in `owner.ex`, which does not move; storage and corruption errors switch to `:recovery` (2056-2067); the `command/2` read fences before it replies (241). ManualLane `:gateway_recovery` reads `status/1` | A | Stays in Gateway |
| Capability gate `capability === state.protected_capability`, and `authority_mode` routing (`:legacy_authority_mode_active`, `:legacy_protected_route_retired`) | 213-331 | Stays in Gateway |
| Refusal atoms: about 60 distinct `{:error, …}` reasons, plus the stored reason strings `"revision_conflict"`, `"quarantine_requires_single_operation"`, `"protected_rejection"`, `"protected_quarantine"`, `"duplicate_receipt"`, `"atomic_bundle_rejected"` | B and C | Pure move; the sorted set from `grep -oE '\{:error, *\{?:[a-z_]+'` over the four files equals the set at base |
| Fault points and halt codes: `inject/2` points; `System.halt` 71 (2052), 72 (1539) and 74 (2186) | B and D | Pure move; the crash fixtures in `test/support/` keep their codes |
| Reopen-ready: every committed state reopens `:ready` | `Authority.read` checks inside each transaction (993, 1060, 1110, 1603, 1641) | Pure move; `reopen_property_test` plus the `*_restart_probe_test` files |
| FR-08A pinned identity | `fr08a_protected_boundary.ex:18-51` pins 10 files; the test asserts `length(exercised_api) == 10` | One operator rebind for the whole move. The pin list must grow (below) |
| Boundary rules 1 and 3 | `architecture_boundary_test.exs` scans `lib/foundry/durable_store/**/*.ex` | New files fall under the glob automatically. Gateway's only role word is a comment (1408), and rule 3 ignores comments |

**FR-08A pins: the list must grow.** [Rule 5](../BOUNDARY-RULES.md) says every guarantee Core
owns lives in a pinned file. The CAS, idempotency, transaction and fencing code leaves
`gateway.ex`, so `DomainCommit` and `AtomicBundle` must be pinned. `Maintenance` must be
pinned too, since it will hold the backup-equality and checkpoint-equality checks (it is
unpinned today). That makes 10 + 3 = 13 pins, or 12 if ML-DEAD-ROUTES removes
`ProtectedVerifier` (§5). `bin/rebind_fr08a.exs` only rewrites values that already exist:
it builds `{old_sha, new_sha}` and `{old_md5, new_md5}` pairs per pinned entry and applies
each with `String.replace/3` over the whole provider and test (30-49). So one placeholder
per tuple would be overwritten twice with the sha256, and the binding would stay
`mismatch`. The lead's steps, on the integrated HEAD that contains M1-M3 and T1-T2:

1. In `lib/foundry/repair/fr08a_protected_boundary.ex`, add the three tuples by hand with
   **two distinct placeholders each, six in total**, none a substring of any other text in
   the provider or test: `"pin-sha256-domaincommit"`/`"pin-md5-domaincommit"`,
   `"pin-sha256-atomicbundle"`/`"pin-md5-atomicbundle"`,
   `"pin-sha256-maintenance"`/`"pin-md5-maintenance"`. In
   `test/foundry/repair/fr08a_protected_boundary_test.exs:12`, change `== 10` to `== 13`
   (`== 12` without `ProtectedVerifier`). The test's per-file source lines (45-49) cover
   only `gateway.ex` and `protected_primitives.ex`, so the new modules need none.
2. **Commit** those two files. The script raises on a dirty tree (16-17) and binds the
   subject to `HEAD`.
3. `MIX_ENV=test mix run --no-start bin/rebind_fr08a.exs`. It prints `old -> new` for every
   changed value; check that all six placeholders appear.
4. Regenerate the frozen report **in a fresh VM**, with the command the script prints
   (52-56): `MIX_ENV=test mix run --no-start -e 'File.write!("docs/fr-08/fr08a-protected-report.txt", Foundry.Repair.FR08AProtectedBoundary.report_artifact())'`.
   The test asserts byte-equality with this file (test line 41).
5. `TMPDIR=/private/tmp MIX_ENV=test mix test test/foundry/repair/fr08a_protected_boundary_test.exs`
   must be green, and the report must say `ready=true`. Commit the provider, the test and
   the report as the rebind commit.

The developer proves only that FR-08A is red in a scratch worktree and never commits a
rebind.

## 4. Commit sequence

Moves come first and tidy-ups after, with one lead rebind at the end. Every commit must pass
`mix compile --force --warnings-as-errors`, `mix format --check-formatted` and
`architecture_boundary_test.exs`. `fr08a_protected_boundary_test` is expected to stay red
until the rebind.

| # | Commit | Mechanical change | Proof | Size |
|---|---|---|---|---|
| M1 | Move region D into `Maintenance` | Cut 2098-2433. Moved functions that Gateway calls go from `defp` to `def` with `@doc false`. Gateway call sites become `Maintenance.f(`. | Move check (below); `operational_storage_test`, `fr08a_fr19a_integration_test`, `sync_fault_test`, `gateway_test` | ≈ −336 +345 |
| M2 | Move region B into `DomainCommit` | Cut 491-551, 1471-2054, 2069-2075 and 2450-2455. `defp` goes to `def`, with `@doc false`, only for the 3 functions Gateway calls and the 9 that C calls. Aliases follow the calls. | Move check; `gateway_test`, `review_corrections_test`, `authority_test`, `fr08a_critical_corrections_test`, `live_refusal_probe_test`, `unified_contract_test` | ≈ −660 +675 |
| M3 | Move region C into `AtomicBundle` | Cut 553-1469. Gateway's `atomic_domain_request/1` and `domain_read_namespaces/0` become `defdelegate`. C's calls into B become `DomainCommit.f(`. | Move check; `atomic_bundle_test`, `domain_read_check_test`, `reopen_property_test`, `*_restart_probe_test`, `quarantine_exit_probe_test`, `test/foundry/manual_lane/*` | ≈ −917 +925 |
| T1 | Delete duplicates | `publication_reconstruction/1` and `replay_evidence/1` become one function. After M1, Maintenance holds three copies of `SELECT coalesce(max(seq), 0) FROM events`: the two moved from D (2103, 2170) and its own `last_sequence/1` (maintenance.ex:42-47). They become one call. `current_seq/1` (1946) is in B and stays in DomainCommit. | `operational_storage_test`, `fr08a_fr19a_integration_test` | ≈ −20 |
| T2 | Update citations | Change the `gateway.ex` paths in [the workflow contract](../WORKFLOW-CONTRACT.md#enforcement-matrix) (rows at lines 178 and 184) and the comment at `domain_read_check_test.exs:75`. [The durable store](../DURABLE-STORE.md) names only the module and its API, which stay true, so it needs no edit. `REPAIR-PLAN.md:240`'s "`gateway.ex` (2,377)" is a dated figure; leave it. Leave function names alone: those rows cite `check_expected_revisions/4` and `protected_discriminator/3`, and neither is renamed. | `elixir bin/check_docs.exs` | docs only |
| R | FR-08A rebind (the lead's commit) | Pins grow to 13 (or 12), then run the rebind script as in §3 | `fr08a_protected_boundary_test` green; report `ready=true` | 3 files |

**Move check (M1-M3).** The check compares compiled definitions, not source. Source AST
cannot see alias or attribute resolution. For example, `gateway.ex:13-25` aliases
`Foundry.DurableStore.Kernel` over Elixir's `Kernel`, and `normalize_candidate/1` (1475)
calls `Kernel.normalize_bundle/1`. A `DomainCommit` that forgot the alias would have an
AST-identical clause that means something else. The implementer ships the check as a
committed script so the protected_primitives split can reuse it and the reviewer can rerun
it:

1. Build the base in a scratch worktree (`git worktree add --detach <dir> e74fb88`,
   `MIX_ENV=test mix compile`), and build the candidate the same way.
2. For each of `Gateway` and `Maintenance` at base, and `Gateway`, `DomainCommit`,
   `AtomicBundle` and `Maintenance` in the candidate, read
   `{:ok, {mod, [debug_info: {:debug_info_v1, backend, data}]}} = :beam_lib.chunks(beam, [:debug_info])`,
   then `{:ok, %{definitions: defs}} = backend.debug_info(:elixir_v1, mod, data, [])`. Each
   definition is `{{name, arity}, kind, meta, clauses}`, with aliases expanded to full module
   atoms, attributes inlined and `__MODULE__` substituted. I checked this against the base
   build: `Gateway` yields 131 definitions (25 `def`, 106 `defp`), `normalize_candidate/1`
   calls `Foundry.DurableStore.Kernel.normalize_bundle`, and `open/2` contains the inlined
   `5000`.
3. Normalise: strip all meta, map `defp` to `def`, and rewrite a remote call
   `{{:., _, [M, f]}, _, args}` whose `M` is one of the four modules into the local call
   `{f, [], args}`.
4. Assert that the multiset of candidate definitions equals the base multiset plus exactly
   the declared `defdelegate`s (`atomic_domain_request/1` and `domain_read_namespaces/0` on
   `Gateway`).

This proves that the compiler saw the same expanded body for every moved function, apart
from the module rename. Also keep the grep counts from §3 (`Database.transaction`, the
digest literals, the refusal-atom set, `System.halt`) and read
`git diff --color-moved=plain --color-moved-ws=allow-indentation-change`. `mix format` will
reflow lines that grow a `DomainCommit.`, `AtomicBundle.` or `Maintenance.` prefix past the
line limit, so reflowed lines are expected. The definition check, not the diff, is the
authority.

**Deliberately not done:** renaming `do_*` functions. That costs citations and buys nothing.
Merging the two `inject/2` vocabularies (Gateway 2047-2054 and ProtectedPrimitives 737-739) is
also left for the protected_primitives split. Dropping the `protected` parameter is §5's job.
T4 (narrowing `read_operational_health` to `(conn, path)`) is optional, and I recommend
skipping it.

## 5. If ML-DEAD-ROUTES deletes `transact_verified` and `ProtectedVerifier`

| Change | Where today | Effect on this design |
|---|---|---|
| The `transact_verified/6` wrapper and `handle_call` clauses go | 60-66, 200-232 | The public API loses one function, and 8 test files and 2 crash fixtures drop their calls (ML-DEAD-ROUTES' job) |
| `do_verified_transact/6` and the `ProtectedVerifier` alias go | 22, 523-551 | DomainCommit shrinks by about 30 lines; the pins go 10 → 9 before this design adds 3 |
| The `protected` argument is always `%{}`: `transact` passes `%{}` (193) and the bundle path passes `%{}` (969) | `commit_bundle`, `commit_accepted_bundle`, `check_expected_revisions`, `touched_revisions` | New tidy-up **T3**: drop the argument and delete `insert_generations`, `insert_claims` and `insert_reservations` (1830-1885), about −70 lines. It is a semantic change, so it needs its own review and a reopen-ready test, not the move check |
| `:legacy_protected_route_retired` loses its only producer | 217 | Refusal-atom set shrinks by one. The invariant table is updated in the ML-DEAD-ROUTES delta, not here |

Order: **ML-DEAD-ROUTES lands first.** A deletion makes the moves smaller, and a deletion
after the moves would cite stale paths. If it lands second, it deletes the same functions
from `DomainCommit` and `Gateway`, and T3 follows it.

## 6. Shared seams with the protected_primitives design

| Seam | Today | Proposal |
|---|---|---|
| S1: Gateway → ProtectedPrimitives calls | `authority_mode`, `execute`, `query`, `snapshot` (from A); `supported_operation_type?`, `required_revisions`, `execute_in_transaction`, `required_bundle_prestate_revisions`, `persist_nonstart_settlement`, `infrastructure_discriminator_at_revision` (from C); `root_command_id_exists?` (from B) | The protected_primitives split keeps `ProtectedPrimitives` as the facade for these 11 functions. Otherwise it edits call sites in three of this design's files |
| S2: ProtectedPrimitives → `atomic_domain_request/1` | `protected_primitives.ex:6048` | Default: keep the `Gateway` delegate, so ProtectedPrimitives needs no edit. The cycle-free alternative moves the 14 lines (1345-1358) into `RecordCodec`, which defines stored-row shapes. That puts a one-line edit in ProtectedPrimitives (operator question Q2) |
| S3: `inject/2` fault vocabulary duplicated | `gateway.ex:2047-2054`, `protected_primitives.ex:737-739` | Leave both copies. If one is ever merged, the protected_primitives split owns it |
| S4: `root_commands` read by SQL in C | `existing_atomic_bundle` (650) | Leave. The table name is Core-internal |
| S5: FR-08A rebind | Both designs change pinned files | One rebind per landed split, run serially ([sweep](../fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md): "serial by rebind") |

No protected_primitives design note exists at this base, so S1-S5 are the surface to
re-check when it lands.

**Which lands first: the Gateway split.** It is smaller (M against L), it touches
ProtectedPrimitives at zero lines (or one, under the Q2 alternative), and it proves the move
check on 2.4k lines before it is run on 8k. Keeping the S1 facade makes the order
irrelevant except for the rebind.

## 7. Risks

| Risk | Mitigation |
|---|---|
| A moved `defp` that becomes `def` widens what other Core modules can call | Mark it `@doc false`. Only the 20 functions listed in §2 are widened, and the move check enforces that list |
| A function's default argument (`commit_accepted_bundle/9` and `commit_rejected_command/7` default `durable_owner`) generates extra arities that could be called by accident | The move check compares clauses, not arities; the 8/6-arity forms stay local-only by convention |
| A parallel ticket (ML-DEAD-ROUTES, the protected_primitives split) edits `gateway.ex` mid-move | Rebase before each M commit; the move check is rerun against the new base |
| Line citations in `docs/fr-08/*` go stale | Those are dated records; the sweep treats them as history. Only the live docs in T2 are updated |
| A fixture recompiles `gateway.ex` source that no longer contains the moved code | Only `def command` is spliced, and it stays |

## 8. Operator questions (recorded, not decided)

- **Q1.** Should `Maintenance` be pinned, making 13 pins? The alternative is to put the
  operational code in a new pinned `Operations` module and leave `Maintenance` unpinned.
  The design assumes pinning `Maintenance`.
- **Q2.** Should seam S2 be broken now, by moving `atomic_domain_request` to `RecordCodec`,
  or should the existing Core back-edge stay as a `Gateway` delegate? The design assumes the
  delegate.
- **Q3.** Should the move check ship as a committed `bin/` script, which the design assumes,
  or be run once and quoted in each commit message?
- **Q4.** If ML-DEAD-ROUTES lands, is T3 (dropping the `protected` argument and the three
  protected inserts) in scope for ML-DECOMPOSE-GATEWAY, or is it its own ticket?
