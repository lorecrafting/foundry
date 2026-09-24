# Decomposing protected_primitives.ex

Status: **design only, for review before implementation** (ticket ML-DECOMPOSE-PP-DESIGN;
Protected Core designs are reviewed first, per the [agent brief](../AGENT-BRIEF.md)).
Nothing here is implemented. Checked against `main` `e74fb8803cb2`, where
[`protected_primitives.ex`](../../lib/foundry/durable_store/protected_primitives.ex) is
8,191 lines: one module, 335 function groups (name/arity), 12 of them public.

**Method.** The call graph comes from parsing the file with `Code.string_to_quoted/2`,
grouping `def`/`defp` clauses by name/arity and recording every call, including `&f/n`
captures, to another local group. External callers come from `grep -rn ProtectedPrimitives
lib test`. All line numbers are at `e74fb88`. "Clause lines" count function clauses only;
comments, attributes and blank lines make up the other ~1,100 lines. The implementer's
checker (C0 below) recomputes every count here, so none of them needs to be taken on
trust.

## 1. Who calls the module today

| Public function | lib callers | test callers |
|---|---|---|
| `supported_operation_type?/1` | `gateway.ex:611` | `transition_plan_test.exs:1086` |
| `execute/5` | `gateway.ex:261` | — |
| `execute_in_transaction/4` | `gateway.ex:740` (inside the gateway's bundle transaction) | — |
| `required_revisions/2` | `gateway.ex:732` | — |
| `required_bundle_prestate_revisions/3` | `gateway.ex:824`, `manual_lane/replay.ex:118` | `decide_e2e_test.exs:206` |
| `persist_nonstart_settlement/3` | `gateway.ex:924` | — |
| `infrastructure_discriminator_at_revision/3` | `gateway.ex:1302` | `atomic_bundle_test.exs:1027–1114` (7) |
| `authority_mode/1` | `gateway.ex:215` (transact_verified), `:256`, `:290` | — |
| `query/2` | `gateway.ex:324`, `manual_lane/log.ex:105,124,143` | — |
| `root_command_id_exists?/2` | `gateway.ex:1911` | — |
| `snapshot/2` | `gateway.ex:343` | — |
| `validate/1` | `authority.ex:82` (the restart check, run on open) | named in 5 probe-test comments |

Other references by name: `architecture_boundary_test.exs:47–49` (rule 3 role sites),
`fr08a_protected_boundary.ex:28` (the pin), and the Quint specs (§6). Every test except
`architecture_boundary_test.exs` reaches the module through `Gateway`, so a split that
keeps these twelve names leaves every caller as it is.

## 2. Target modules

Eight new modules go in `lib/foundry/durable_store/protected/`, and the old file stays
as the facade. The gate's `@core` glob (`lib/foundry/durable_store/**/*.ex`) is
recursive, so rules 1–3 already cover the subdirectory. Every module is
`@moduledoc false`.

| Module (`Foundry.DurableStore.…`) | Owns (why this is a seam) | Takes, by current line runs | Public API | Fns / clause lines |
|---|---|---|---|---|
| `ProtectedPrimitives` (facade, same path) | The command pipeline: normalize → idempotency → envelope → apply → one result row plus its `durable_operations` mirror, all inside one transaction. Fault-injection points. Owns tables `root_commands` and `durable_operations` (`protected_v1`). | 18–127, 357–548, 628–634, 702–739, 2638–2651, 2666–2675, 2684–2743 | The 12 names in §1, unchanged. Seven become `defdelegate` (below) | 16 / 419 |
| `Protected.Rows` | Converts each `root_*` table row to and from a map, gives the public fact shape (`public_effect/1`, …) and loads, inserts and updates single rows. It is the single `encode`/`decode` path, so the bytes the writer encodes are the bytes `validate_encoded_rows/3` re-encodes. It holds the `protected-command` and `root-receipt` digest functions and the shared vocabulary attributes. It is the lowest layer and calls no sibling. | 550–551, 1641–1659, 2677, 2745–2772, 2786–3120, 3138–3224, 3564–3578, 3619–3646, 3707, 3813–4012, 4025–4045, 4084–4191, 4279–4293, 4301–4316, 8115–8190 | 60 former `defp`s become public. New: `operation_types/0`, `closed_effect_statuses/0` | 66 / 900 |
| `Protected.Guards` | Admission checks that only read. Each returns `:ok` or `{:error, refusal}` and never writes. These are the Core rows of the [enforcement matrix](../WORKFLOW-CONTRACT.md#enforcement-matrix): control active, predecessor currency, non-start allowance, attempt open, reviewer independence, lease availability and the role→dimension map. The module also holds the one reader of `infrastructure_attempt_limits` for both `nonstart_allowance/3` and the discriminator. | 317–354 (with `@doc`/`@spec`), 2774–2784, 3226–3251, 3271–3527, 3584–3615, 3668–3705, 3710–3803 | 20 former `defp`s, plus `infrastructure_discriminator_at_revision/3`. New: `dimensions/0` | 28 / 431 |
| `Protected.ReadSet` | The read-key vocabulary (`ledger/<id>/<gen>`, `settlement/<id>`, `claim/<id>`, closure and lineage keys) and current-revision lookup. This is the CAS contract between a protected command and the store. It only reads, and its consumers are the facade, gateway bundle staging and manual-lane replay. | 130–188, 1661–1693, 1907–1925, 2150–2636, 2653–2664, 3136 | `required_bundle_prestate_revisions/3`, `complete_read_set/3`, `required_reads/2`, `normalize_read_set/1` | 25 / 591 |
| `Protected.Operations` | The 18 transitions (`apply_operation/2` clauses 741–1629) and their cascades: control fence, subtree close, cancel, settle and quarantine. It is the only module that changes `root_*` state through `Rows`. It owns the write order inside each transition and the mapping from `{:error, x}` to `{:reject, x, %{}}`. It also owns the non-start settlement writer (table `root_infrastructure_settlements`). | 191–315, 741–1639, 1695–1904, 1932–2148, 3253–3269, 3529–3562, 3648–3666, 3806–3811, 4014–4023, 4047–4082, 4193–4277 | `apply_operation/2`, `persist_nonstart_settlement/3` | 32 / 1,635 |
| `Protected.Query` | The read API: the `query/2` types, `snapshot/2`, `authority_mode/1`, and the bounded effect page, which has its own size limits (`@effect_observation_*`), its own cursor digest tags and its own read transaction (4320). | 554–625, 637–665, 4295–4299, 4318–5338 | `query/2`, `snapshot/2`, `authority_mode/1` | 51 / 1,074 |
| `Protected.Replay` | Part of the restart check. It replays the typed transitions in `root_commands` history and compares the result with the current ledger, reservation, effect and claim rows (6671–7352). It also checks that each current row equals its last transition snapshot (7354–7777). It depends only on `Rows`. | 6671–7777 (one contiguous run) | `validate_typed_transition_replay/1`, `validate_current_transition_provenance/1` | 49 / 1,029 |
| `Protected.BundleCheck` | Part of the restart check. It checks what the gateway wrote: `atomic_bundles` (`atomic-bundle-v2` digest), `durable_operations`, `root_infrastructure_settlements`, plan binding (re-run through `TransitionPlan.bind/3`) and discriminator reconstruction. It is the reader for writes made in `gateway.ex` (§5). | 5498–5519, 5546–6282 | `validate_atomic_bundle_rows/1` | 27 / 692 |
| `Protected.RestartCheck` | `validate/1`: the per-table blob and shape checks, history chains, pointers, inboxes, ledger tree, and effect, claim, receipt and reservation provenance. It runs `BundleCheck` and `Replay`. | 668–700, 5340–5496, 5522–5544, 6284–6669, 7779–8113 | `validate/1` | 41 / 898 |

The facade's `defdelegate`s are `required_bundle_prestate_revisions/3` → `ReadSet`,
`persist_nonstart_settlement/3` → `Operations`, `infrastructure_discriminator_at_revision/3`
→ `Guards`, `authority_mode/1`, `query/2` and `snapshot/2` → `Query`, and `validate/1` →
`RestartCheck`. The facade imports only what it calls, with `only:`, so a delegate never
clashes with an imported name.

**Dependency direction.** These edges were measured from the call graph after assignment.
There are no cycles.

```
Rows  <-  Guards, ReadSet, Query, Replay
Guards  <-  Operations, BundleCheck, RestartCheck
BundleCheck, Replay  <-  RestartCheck
Facade  ->  Rows, ReadSet, Operations   (calls)
Facade  ->  Guards, Query, RestartCheck (defdelegate only)
```

Two placements were chosen to break edges. `inbox_fact/2` and `ledger_fact/3` go to `Rows`,
not `Query`, because commands return the same fact shape that queries do; otherwise
`Operations → Query` would be an edge. `@operation_types` goes to `Rows`, not the facade,
because `ReadSet` needs it and the facade imports `ReadSet`.

**Shared attributes.** Each is defined once. A consumer declares `@x Owner.x()`, so every
body that reads `@x` stays byte-identical, and no role token is copied.

| Attribute | Owner | Also read by |
|---|---|---|
| `@operation_types` | `Rows` | facade (18, 439, 2645), `ReadSet` (2182) |
| `@closed_effect_statuses` | `Rows` | `Operations` (1609), `Replay` (6830) |
| `@dimensions` (rule 3 site) | `Guards` | `Operations` (874), `RestartCheck` (6346) |
| `@closed_reservation_statuses` | `Operations` | — |
| `@effect_observation_*` (6) | `Query` | — |

`Operations` stays the largest module at 1,635 clause lines. It could only be split
(ledger transitions / effect transitions) with a cycle. `close_generation` cancels
effects, and `cancel_effect` and `settle_claim` release and settle reservations. This
design keeps it whole (Q7).

## 3. Invariants that must not change

Every move keeps function bodies AST-identical (§4). That keeps the first five rows by
construction. The table records where each one is enforced so that a reviewer can
spot-check it.

| Invariant | Enforced today | After the split |
|---|---|---|
| **Digest domain tags and inputs** (7 tags, 11 sites) | `protected-command-v1` 2679 (writer `request_digest/2`, reader 5340ff via the same fn); `authenticated-inbox-item-v1` 776 (writer) / 6323 (reader); `effect-request-v1` 1250 / 6554; `root-receipt-v1` 4091 (`receipt_digest/1`, also used by `Replay`) / 7983; `effect-observation-scope-v1` 4375, `-source-v1` 4379 (cursor binding); `atomic-bundle-v2` 5571, 5615 (reader; the writer is `gateway.ex:592`) | `Rows`: command and receipt functions. `Operations` and `RestartCheck`: the inbox-item and effect-request writer and reader copies. `Query`: cursor tags. `BundleCheck`: the bundle tag. Check: the multiset of `"foundry-*"` literals across the new files equals the old file's |
| **Transaction boundaries** | `execute_new/6` 358 (apply and persist in one transaction) and 393 (a semantic rejection rolls back, then persists a rejected result in a second transaction). `execute_in_transaction/4` opens none, because the gateway's transaction owns it (`gateway.ex:666`). The effect page reads in one transaction (4320) | The first two stay in the facade and the third in `Query`. No new module opens a transaction |
| **Write order** | Inside each transition (e.g. `create_effect` 1318–1321: effect, then reservations, then leases). In `persist_committed_result/8` 421–424, `root_commands` must be inserted before `persist_v1_operation/2` copies from it, and then comes `inject(:before_commit)` | Bodies are unchanged, so the order is unchanged |
| **Fault points** | `:before_commit` / `{:halt, :before_commit}` (737–738, exit 71), `:after_commit_before_reply` (36) | Stay in the facade. Proved by `sync_fault_test.exs` and `operational_storage_test.exs` |
| **Refusal atoms** | 43 distinct `{:reject, atom, _}` literals, one `{:quarantine, :conflicting_receipt, _}`, plus the `when reason in [...]` lists (e.g. 1331–1350) and `{:error, atom}` refusals from `Guards` | AST equality keeps each literal |
| **FR-08A pinned identity** | [`fr08a_protected_boundary.ex:18–52`](../../lib/foundry/repair/fr08a_protected_boundary.ex) pins 10 modules: `Authority`, `Database`, `Gateway`, `ProtectedPrimitives`, `Kernel` (DurableStore), `RecordCodec`, `Encoding`, `FR08HandoffGate`, `TransitionPlan`, `ProtectedVerifier` | See the next paragraph |
| **Rule 3 role sites** | `@role_sites`: `{ProtectedPrimitives, {:@, :dimensions}}`, `{…, {:def, :persist_nonstart_settlement}}` (token at 203), `{…, {:defp, :required_dimension}}` | Three keys renamed: `{Protected.Guards, {:@, :dimensions}}`, `{Protected.Guards, {:def, :required_dimension}}`, `{Protected.Operations, {:def, :persist_nonstart_settlement}}`. The count is unchanged, but the list is edited (Q2) |
| **Reopen-ready** (every committed state reopens `:ready`) | Writer and checker must agree. Proved by `reopen_property_test.exs` and the `*_restart_probe_test.exs` files | The split puts the writer (`Operations`) and its checker (`RestartCheck`/`Replay`/`BundleCheck`) in different files. Each new file opens with a header comment naming its pair file. Run the property test at every move commit |

**FR-08A pin.** The split changes the facade's sha256 and BEAM md5. Every move commit
does this, so `fr08a_protected_boundary_test.exs` is red from C1 until the rebind.
**The pin list must grow.** Otherwise about 7,700 of the 8,200 lines would be unpinned,
the facade pin would protect only the pipeline and delegates, and
[boundary rule 5](../BOUNDARY-RULES.md) ("every guarantee Core owns lives in an
attestation-pinned file") would be broken. Add the eight `Protected.*` modules: 10 → 18
entries, or 17 if ML-DEAD-ROUTES removes `ProtectedVerifier` first. Edit the test's
`length(report.identity.exercised_api) == 10` to match. The existing
[`bin/rebind_fr08a.exs`](../../bin/rebind_fr08a.exs) only replaces existing values: it
matches old strings with `String.replace`. So new entries must be added by hand with
their real sha256 and md5, not a shared placeholder, which the first replacement would
overwrite everywhere. After that, one operator rebind covers the series.

## 4. Commit sequence

**Pure-move check (C0).** A committed `bin/check_pure_move.exs BASE OLD NEW...` passes
only if all of the following hold:
1. Every name/arity group of `OLD@BASE` occurs in exactly one `NEW` file, AST-equal
   clause by clause after stripping metadata and mapping `:defp` → `:def`. AST rather
   than bytes, because `mix format` may re-join a head that `defp` → `def` makes one
   character shorter.
2. `NEW` defines nothing else except the listed delegates and the three accessors
   `Rows.operation_types/0`, `Rows.closed_effect_statuses/0` and `Guards.dimensions/0`.
3. Every old attribute is either owned with the same value or declared `@x Owner.x()`.
4. Every old comment line occurs in `NEW`, and the only new comments are the file header
   comments above `defmodule`. The multiset of `"foundry-*"` literals is unchanged.

Moved bodies keep unqualified calls through `import` of the lower modules. That is what
keeps them identical, and the absence of name clashes follows from all names coming from
one file. Red control: flip one atom in a moved body and confirm the check fails. The
reviewer's second view is `git diff --color-moved=dimmed-zebra
--color-moved-ws=allow-indentation-change`, in which only headers, `import`/`alias`,
accessors, delegates and `defp` → `def` should remain highlighted.

Each move extracts one module from the facade, lowest layer first, so no step creates a
cycle.

| # | Commit | Moves (fns / clause lines) | Other edits | Focused tests beyond S |
|---|---|---|---|---|
| C0 | Add the pure-move checker and its red control | — | ~100 lines | its self-test |
| C1 | Extract `Protected.Rows` | 66 / 900 | `operation_types/0` and `closed_effect_statuses/0` accessors | everything, since every layer uses Rows |
| C2 | Extract `Protected.Guards` | 28 / 431 | `dimensions/0`; 2 `@role_sites` keys | `live_refusal_probe`, `create_effect_refusal`, `review_independence`, `atomic_bundle` (discriminator) |
| C3 | Extract `Protected.ReadSet` | 25 / 591 | — | `decide_e2e`, `atomic_bundle`, `manual_lane` |
| C4 | Extract `Protected.Query` | 51 / 1,074 | — | `observations_test`, `atomic_bundle` (corrupt page), `manual_lane` (log) |
| C5 | Extract `Protected.Replay` | 49 / 1,029 | — | `reopen_property`, the `*_restart_probe` tests |
| C6 | Extract `Protected.BundleCheck` | 27 / 692 | — | `atomic_bundle`, `reopen_property` |
| C7 | Extract `Protected.Operations` | 32 / 1,635 | 1 `@role_sites` key | `live_refusal_probe`, `quarantine_exit_probe`, `reopen_property` |
| C8 | Extract `Protected.RestartCheck` | 41 / 898 | The facade is now 16 fns / 419 lines plus 7 delegates | `authority_test`, `reopen_property`, all restart probes |
| C9 | Update citations and grow the pin list | — | [workflow contract](../WORKFLOW-CONTRACT.md) matrix rows and lines 676–706; comments at `transition_plan.ex:35` (a pinned file) and `work_packet.ex:240`; spec READMEs; `@api_identity` +8, test length | `architecture_boundary_test`; `elixir bin/check_docs.exs` |
| C10 | FR-08A rebind (by the operator) | — | provider, test, report | `fr08a_protected_boundary_test` green |

**S**, run at every commit:
`test/foundry/durable_store test/foundry/architecture_boundary_test.exs
test/foundry/workflow/decide_e2e_test.exs test/foundry/manual_lane
test/foundry/observations_test.exs`, then `mix compile --force --warnings-as-errors`, then
the C0 check against `e74fb88` (or the rebased base). The only expected failure in C1–C9
is `test/foundry/repair/fr08a_protected_boundary_test.exs`, which is the only test that
reads FR-08A identity. The full gate runs once, on the series tip after C10.

**API tidy-ups are deferred.** Each one changes pinned bytes, so each needs its own rebind:
- **T1:** repoint callers at the owning module and delete the delegates.
- **T2:** give each domain tag one digest function used by its writer and its reader. The
  inbox-item, effect-request and receipt tags are built inline twice today. The inputs
  compare equal at 776/6323, 1250/6554 and 4091/7983, but that is a claim to prove, not a
  move.
- **T3:** qualify calls instead of using `import`.

## 5. Parallel tickets

**ML-DEAD-ROUTES.** It may delete `transact_verified`/`ProtectedVerifier` and
`Foundry.Observations`:

| If deleted | Effect here |
|---|---|
| `transact_verified` + `ProtectedVerifier` | This module does not call `ProtectedVerifier`. Its only link to the route is `authority_mode/1`, called at `gateway.ex:215`. The legacy tables it counts (`claims`, `reservations`, `ledger_generations`, `receipts`, `leases`) are written only by that route (`gateway.ex:1837–1872`). The design is unchanged: `authority_mode/1` stays in `Query` whether or not ML-DEAD-ROUTES simplifies it. The pin list becomes 17. |
| `Foundry.Observations` | `effect_observation_page` stays, because `manual_lane/log.ex:18,105` still consumes it. `observations_test.exs` drops out of S. |

Land ML-DEAD-ROUTES first. If it edits this file (`authority_mode/1` 554–568, `snapshot/2`
660), the assignment is by function name and does not change, but C0's base and every line
run shift. Re-run the check against the new base rather than rebasing move commits by hand.

**Gateway design (parallel ticket).** These seams are shared. Both designs should agree
that the facade names in §1 stay until T1.

| Seam | This file | `gateway.ex` |
|---|---|---|
| `atomic-bundle-v2` envelope digest | reader `BundleCheck` (5571, 5615) | writer 592. If the gateway design extracts an atomic-bundle module, one digest function should serve both |
| Command-id namespace (`commands` ⟷ `root_commands`) | `existing_command/4` and `validate_public_command_identity/2` read `commands` | 1911 reads `root_commands` through `root_command_id_exists?/2` |
| Read-set staging | `ReadSet` | 732, 824; `execute_in_transaction/4` runs inside the gateway transaction at 666/740 |
| Non-start settlement | `Operations.persist_nonstart_settlement/3`, `Guards` discriminator | 924, 1302 |
| Authority-mode gating | `Query.authority_mode/1` | 215, 256, 290 |

## 6. Quint and other citations

[`spec/ledger/ledger.qnt`](../../spec/ledger/ledger.qnt) cites `PP:<line>` 51 times, at
Pramāṇa `df1ac5f8`. These are already stale at `e74fb88` (for example `conserved?`
`PP:3019` is now at 3120). After the split a line needs a file as well. The recommendation
is to cite `Module.function/arity`, which survives both moves and line drift, and to cite
an `apply_operation/2` clause as `Operations.apply_operation/2 "reserve"`. Every existing
citation already names its function, so the rewrite is mechanical:

| Target | ledger.qnt functions cited |
|---|---|
| `Rows` | `conserved?`, `current_generation`, `subtree_ledgers`, `reservations_for_effect/claim`, `settlement_proof`, `@closed_effect_statuses` (PP:8) |
| `Guards` | `reservations_open?`, `release_guard`, `load_effect_reservations`, `reservation_dimensions`, `attempt_open` |
| `Operations` | every `apply_operation` clause; `release_hold`, `close_subtree`, `revoke_unissued_generation`, `cancel_unissued_effect_owners`, `activate_reservations`, `release_many`, `settle_reservations`, `reservation_settlement`, `settle_with_receipts`, `reconciled_settlement`, `first_settlement`, `quarantine_conflicting_receipt`, `observation_conflict?` |
| `RestartCheck` | `validate_effect_relations`, `validate_ledger_tree`, `validate_reservations` |

The same applies to `spec/fr10/effects.qnt` (40 citations, at `33395c92`),
`spec/core_boundary/core.qnt` (28) and the three spec READMEs (6, 6, 4). This is batch C3
in the [dogfood log](../batch-d/DOGFOOD-LOG.md). Do it once, after C8. Dated records that
cite old lines are evidence and are not rewritten.

## 7. Risks and open questions (recorded, not decided)

| # | Risk | Mitigation or question |
|---|---|---|
| R1 | 87 former `defp`s become `def`. Any `lib` module could call `Rows.update_ledger/3` and bypass `Operations` | The modules are `@moduledoc false` and the facade stays the documented API. Q6 asks whether a gate rule should restrict callers |
| R2 | This is the most contended file (FR-10 commits 2–4 and ML-DEAD-ROUTES touch it). Rebasing move commits across a concurrent edit is error-prone | Freeze edits to this file during C1–C8. Because the assignment is by name, redo the moves on the new base rather than resolving conflicts |
| R3 | Consumer attributes computed from another module's function (`@x Owner.x()`) create compile-time dependencies | Only lower layers are referenced, so there is no compile deadlock. The facade must not own a shared attribute (see `@operation_types` above) |
| R4 | `import` hides where a call resolves | The compiler rejects ambiguous calls. T3 can qualify calls later |
| R5 | C1–C9 are red on FR-08A. [Repair plan](../REPAIR-PLAN.md) FR-23 acceptance says to rebind "in the same commit that changes its subject, never in a follow-up", but practice (`8f7a049`, the rebind script's header) is a follow-up rebind commit | Q3 |

- **Q1.** Is the facade permanent, or does T1 (repoint callers, drop delegates) follow in
  its own ticket with its own rebind?
- **Q2.** Is renaming three `@role_sites` keys in move commits acceptable under rule 3
  ("may shrink, never grow")? The count stays at 4.
- **Q3.** Should the series land as nine commits with FR-08A red until C10, or as one
  squashed move commit plus its rebind? Which reading of the plan's "same commit" rule
  governs?
- **Q4.** Should the pin list grow to 18 (or 17) named modules, or pin the `protected/`
  directory as one identity? Either needs an edit to the provider.
- **Q5.** Should `bin/check_pure_move.exs` stay after the series, for T1–T3 and the
  gateway split, or be deleted in C9?
- **Q6.** Should there be a new gate rule that only `ProtectedPrimitives` and
  `Protected.*` may reference `Protected.*`?
- **Q7.** Should `Operations` (1,635 lines) be split further? It cannot be split without
  first moving the reservation release and settle primitives below both halves.
- **Q8.** Namespace: `Protected.*` in a subdirectory (proposed), or flat
  `Protected*` files next to `protected_verifier.ex`?
