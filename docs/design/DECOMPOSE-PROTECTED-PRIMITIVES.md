# Decomposing protected_primitives.ex

[Foundry](../../README.md) › [Docs](../README.md) › Decomposing protected_primitives.ex

Status: **design only, for review before implementation** (ticket ML-DECOMPOSE-PP-DESIGN;
Protected Core designs are reviewed first, per the [agent brief](../AGENT-BRIEF.md)).
Nothing here is implemented. Checked against `main` `e74fb8803cb2`, where
[`protected_primitives.ex`](../../lib/foundry/durable_store/protected_primitives.ex) is
8,191 lines: one module, 335 function groups (name/arity), 12 of them public.
Revision 2 addresses review 1 and aligns with the corrected gateway design
(ML-DECOMPOSE-GATEWAY, §3–§4 of that note).

**Method.** The call graph comes from parsing the file with `Code.string_to_quoted/2`,
grouping `def`/`defp` clauses by name/arity and recording every call, including `&f/n`
captures, to another local name/arity. A group ends at the highest line of any node in
it, closing delimiters included. External callers come from `grep -rn ProtectedPrimitives
lib test`. All line numbers are at `e74fb88`. "Clause lines" count function clauses only;
comments, attributes and blank lines make up the rest. These are hand measurements for
review. The authoritative counts are the ones the move checker prints (§4).

## 1. Who calls the module today

| Public function | lib callers | test callers |
|---|---|---|
| `supported_operation_type?/1` | `gateway.ex:611` | `transition_plan_test.exs:1086` |
| `execute/5` | `gateway.ex:261` | — |
| `execute_in_transaction/4` | `gateway.ex:740` (inside the gateway's bundle transaction, 666) | — |
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
`fr08a_protected_boundary.ex:28` (the pin), and the Quint specs (§6).

There is one outgoing call to another Core module besides `Database`, `Encoding` and
`TransitionPlan` (5665): `expected_bundle_domain_request/1` calls
`Foundry.DurableStore.Gateway.atomic_domain_request/1` fully qualified (6048). That is
seam S2 in the gateway note. Every test except `architecture_boundary_test.exs` reaches
the module through `Gateway`, so a split that keeps these twelve names leaves every caller
as it is.

## 2. Target modules

Seven new modules go in `lib/foundry/durable_store/protected/`, and the old file stays as
the facade. The gate's `@core` glob (`lib/foundry/durable_store/**/*.ex`) is recursive,
so rules 1–3 already cover the subdirectory. Every module is `@moduledoc false`.

**Names.** `Foundry.ManualLane.Replay` and `Foundry.Observations.Query` already exist, so
revision 1's `Protected.Replay` and `Protected.Query` are renamed to
`Protected.TransitionReplay` and `Protected.Reads`. No other new module's last segment
matches a module in `lib/`, checked with grep over every `defmodule`. Every reference
between split modules is written `Foundry.DurableStore.Protected.X`, and no `as:` is
allowed (§4, check rule 5).

| Module (`Foundry.DurableStore.…`) | Owns (why this is a seam) | Takes, by current line runs | Public API | Fns / clause lines |
|---|---|---|---|---|
| `ProtectedPrimitives` (facade, same path) | The command pipeline: normalize → idempotency → envelope → apply → one result row plus its `durable_operations` mirror, all inside one transaction. Fault-injection points. Owns the tables `root_commands` and `durable_operations` (`protected_v1`). | 18–127, 357–548, 628–634, 702–739, 2638–2651, 2666–2675, 2684–2743 | The 12 names in §1, unchanged. Seven become `defdelegate` (below) | 16 / 419 |
| `Protected.Rows` | Converts each `root_*` table row to and from a map, gives the public fact shape (`public_effect/1`, …) and loads, inserts and updates single rows. It is the single `encode`/`decode` path, so the bytes the writer encodes are the bytes `validate_encoded_rows/3` re-encodes. It holds the `protected-command` and `root-receipt` digest functions and two shared attributes (`@operation_types`, `@closed_effect_statuses`). It is the lowest layer and calls no sibling. Its 12 writers are fenced by rule 13 (§3). | 550–551, 1641–1659, 2677–2682, 2745–2772, 2786–3134, 3138–3224, 3564–3578, 3619–3646, 3707–3708, 3813–4012, 4025–4045, 4084–4191, 4279–4293, 4301–4316, 8115–8190 | 60 former `defp`s. New: `operation_types/0`, `closed_effect_statuses/0` | 66 / 920 |
| `Protected.Guards` | Admission checks that only read. Each returns `:ok` or `{:error, refusal}` and never writes. These are the Core rows of the [enforcement matrix](../WORKFLOW-CONTRACT.md#enforcement-matrix): control active, predecessor currency, non-start allowance, attempt open, reviewer independence, lease availability and the role→dimension map. It is the one place that reads `infrastructure_attempt_limits`, for both `nonstart_allowance/3` and the discriminator. It holds `@dimensions` so that it sits next to `required_dimension/2` (both are rule 3 sites). | 317–354 (with `@doc`/`@spec`), 2774–2784, 3226–3251, 3271–3527, 3584–3615, 3668–3705, 3710–3803 | 19 former `defp`s, plus `infrastructure_discriminator_at_revision/3`. New: `dimensions/0` | 28 / 432 |
| `Protected.ReadSet` | The read-key vocabulary (`ledger/<id>/<gen>`, `settlement/<id>`, `claim/<id>`, closure and lineage keys) and current-revision lookup. This is the CAS contract between a protected command and the store. It only reads, and its consumers are the facade, gateway bundle staging and manual-lane replay. | 130–188, 1661–1693, 1907–1925, 2150–2636, 2653–2664, 3136 | `required_bundle_prestate_revisions/3`, `complete_read_set/3`, `required_reads/2`, `normalize_read_set/1` | 25 / 592 |
| `Protected.Operations` | The 18 transitions (the `apply_operation/2` clauses at 741–1629) and their cascades: control fence, subtree close, cancel, settle and quarantine. It is the only caller of `Rows`' writers apart from the facade's result row. It owns the write order inside each transition, the mapping from `{:error, x}` to `{:reject, x, %{}}`, and the non-start settlement writer (`root_infrastructure_settlements`). | 191–315, 741–1639, 1695–1904, 1932–2148, 3253–3269, 3529–3562, 3648–3666, 3806–3811, 4014–4023, 4047–4082, 4193–4277 | `apply_operation/2`, `persist_nonstart_settlement/3` | 32 / 1,636 |
| `Protected.Reads` | The read API: the `query/2` types, `snapshot/2`, `authority_mode/1`, and the bounded effect page, which has its own size limits (`@effect_observation_*`), its own cursor digest tags and its own read transaction (4320). | 554–625, 637–665, 4295–4299, 4318–5338 | `query/2`, `snapshot/2`, `authority_mode/1` | 51 / 1,077 |
| `Protected.TransitionReplay` | Part of the restart check. It replays the typed transitions in `root_commands` history and compares the result with the current ledger, reservation, effect and claim rows (6671–7352). It also checks that each current row equals its last transition snapshot (7354–7777). It is a self-contained re-execution algorithm that depends only on `Rows`. | 6671–7777 (one run) | `validate_typed_transition_replay/1`, `validate_current_transition_provenance/1` | 49 / 1,055 |
| `Protected.RestartCheck` | `validate/1`: the per-table blob and shape checks, history chains, pointers, inboxes, ledger tree, and effect, claim, receipt and reservation provenance. It includes the atomic-bundle section (5498–6282): `atomic_bundles`, `durable_operations` and `root_infrastructure_settlements`, with plan binding through `TransitionPlan.bind/3` and the discriminator. It runs `TransitionReplay`. | 668–700, 5340–6669, 7779–8113 | `validate/1` | 68 / 1,598 |

The facade's `defdelegate`s are `required_bundle_prestate_revisions/3` → `ReadSet`,
`persist_nonstart_settlement/3` → `Operations`, `infrastructure_discriminator_at_revision/3`
→ `Guards`, `authority_mode/1`, `query/2` and `snapshot/2` → `Reads`, and `validate/1` →
`RestartCheck`. The facade imports only what it calls, with `only:`, so a delegate never
clashes with an imported name.

**`BundleCheck` is folded into `RestartCheck`,** which revision 1 kept separate. Its only
caller is `validate/1`, and folding it adds no edge, because `RestartCheck` already
depends on `Guards` and `Rows`. The reopen-ready pair (§3) becomes `Operations` ↔
`RestartCheck` + `TransitionReplay` instead of three checker files. The seam with the
gateway's writer is still named: it is the contiguous run 5498–6282 inside `RestartCheck`.
`TransitionReplay` stays separate because it is an algorithm of its own.

**Allowed edges.** These were measured from the call graph after assignment. The list is
closed: any edge not listed is a defect, and that includes a compile-time edge from an
`@x Owner.x()` attribute. There are no cycles. This is the list an xref-graph test
compares against.

| From | May depend on (split set) | May depend on (outside the split) |
|---|---|---|
| `Protected.Rows` | — | `Database`, `Encoding` |
| `Protected.Guards` | `Rows` | `Database`, `Encoding` |
| `Protected.ReadSet` | `Rows` | `Database`, `Encoding` |
| `Protected.Reads` | `Rows` | `Database`, `Encoding` |
| `Protected.TransitionReplay` | `Rows` | `Database`, `Encoding` |
| `Protected.Operations` | `Guards`, `Rows` | `Database`, `Encoding` |
| `Protected.RestartCheck` | `TransitionReplay`, `Guards`, `Rows` | `Database`, `Encoding`, `TransitionPlan` (5665), `Gateway` (`atomic_domain_request/1`, 6048; seam S2) |
| `ProtectedPrimitives` (facade) | calls into `Rows`, `ReadSet` and `Operations`; `defdelegate` only to `Guards`, `Reads` and `RestartCheck` | `Database`, `Encoding` |

The "Database, Encoding" column is an upper bound. A module that never uses one of them
simply has fewer edges than listed, and the checker only fails on an edge that is not in
the list.

Two placements were chosen to break edges. `inbox_fact/2` and `ledger_fact/3` go to `Rows`,
not `Reads`, because commands return the same fact shape that queries do; otherwise
`Operations → Reads` would be an edge. `@operation_types` goes to `Rows`, not the facade,
because `ReadSet` needs it and the facade imports `ReadSet`.

**Shared attributes.** Each is defined once. A consumer declares `@x Owner.x()`, so every
body that reads `@x` stays unchanged, and no role token is copied. After compilation the
attribute is inlined, so the definitions compare equal (§4).

| Attribute | Owner | Also read by |
|---|---|---|
| `@operation_types` | `Rows` | facade (18, 439, 2645), `ReadSet` (2182) |
| `@closed_effect_statuses` | `Rows` | `Operations` (1609), `TransitionReplay` (6830) |
| `@dimensions` (rule 3 site) | `Guards` | `Operations` (874), `RestartCheck` (6346) |
| `@closed_reservation_statuses` | `Operations` | — |
| `@effect_observation_*` (6) | `Reads` | — |

`Operations` (1,636 lines) and `RestartCheck` (1,598) are the largest modules. `Operations`
could only be split into ledger and effect transitions with a cycle: `close_generation`
cancels effects, and `cancel_effect` and `settle_claim` release and settle reservations.
This design keeps it whole (Q5).

## 3. Invariants that must not change

The compiled-definition check (§4) keeps the first five rows by construction. The table
records where each one is enforced so that a reviewer can spot-check it.

| Invariant | Enforced today | After the split |
|---|---|---|
| **Digest domain tags and inputs** (7 tags, 11 sites) | `protected-command-v1` 2679 (writer `request_digest/2`, reader 5340ff via the same fn); `authenticated-inbox-item-v1` 776 (writer) / 6323 (reader); `effect-request-v1` 1250 / 6554; `root-receipt-v1` 4091 (`receipt_digest/1`, also used by `TransitionReplay`) / 7983; `effect-observation-scope-v1` 4375, `-source-v1` 4379 (cursor binding); `atomic-bundle-v2` 5571, 5615 (reader; writer `gateway.ex:592`) | `Rows`: the command and receipt functions. `Operations` and `RestartCheck`: the inbox-item and effect-request writer and reader copies. `Reads`: the cursor tags. `RestartCheck`: the bundle tag. The grep count of each `"foundry-*"` literal equals the count at base |
| **Transaction boundaries** | `execute_new/6` 358 (apply and persist in one transaction) and 393 (a semantic rejection rolls back, then a second transaction persists a rejected result). `execute_in_transaction/4` opens none, because the gateway's transaction at 666 owns it. The effect page reads in one transaction (4320) | The first two stay in the facade and the third in `Reads`. The grep count of `Database.transaction` stays at 3 |
| **Write order** | Inside each transition (e.g. `create_effect` 1318–1321: effect, then reservations, then leases). In `persist_committed_result/8` 421–424, `root_commands` must be inserted before `persist_v1_operation/2` copies from it, and then comes `inject(:before_commit)` | Definitions are unchanged, so the order is unchanged |
| **Fault points** | `:before_commit` / `{:halt, :before_commit}` (737–739, `System.halt(71)`), `:after_commit_before_reply` (36) | Stay in the facade. The duplicate `inject/2` vocabulary (gateway seam S3) is left alone. Proved by `sync_fault_test.exs` and `operational_storage_test.exs` |
| **Refusal atoms** | 43 distinct `{:reject, atom, _}` literals, one `{:quarantine, :conflicting_receipt, _}`, plus the `when reason in [...]` lists (e.g. 1331–1350) and `{:error, atom}` refusals from `Guards` | Definition equality keeps each literal. The sorted grep set equals the set at base |
| **Write path: only the command pipeline reaches `root_*` writes** | Every insert and update is `defp` today (2786–4316), so only the 12 public functions reach them | **New gate rule 13, landing in C1:** in `lib/`, only `Foundry.DurableStore.ProtectedPrimitives` and `Foundry.DurableStore.Protected.*` may reference `Foundry.DurableStore.Protected.*`. There is one declared exception site,
declared the way rule 4 declares `@software_sites`: `@protected_sites [{Foundry.Repair.FR08AProtectedBoundary, {:@, :api_identity}}]`.
The pin provider names these modules and never calls them, and `references/2` walks
attribute values, so without this exception the C9 pin commit would be red. The list may
shrink, never grow. It uses the existing `references/2` scanner (`architecture_boundary_test.exs:184`), which resolves aliases, with a red-control fixture: an aliased `Protected.Rows.update_ledger/3` call from a `lib/foundry/manual_lane` path is found. Test files are exempt, so restart probes may write corrupt rows. The matching sentence goes in [the boundary rules](../BOUNDARY-RULES.md), and `AGENTS.md`'s "twelve rules" becomes thirteen. This closes the boundary-rule-7-class hole that making the 12 `Rows` writers public would otherwise open (`insert_claim/2`, `insert_effect/2`, `insert_ledger/2`, `insert_receipt/2`, `insert_reservation/2`, `insert_simple_history/7`, `update_claim/3`, `update_effect/3`, `update_ledger/3`, `update_reservation/3`, `write_inbox_head/5`, `write_simple/7`) |
| **FR-08A pinned identity** | [`fr08a_protected_boundary.ex:18–52`](../../lib/foundry/repair/fr08a_protected_boundary.ex) pins 10 modules: `Authority`, `Database`, `Gateway`, `ProtectedPrimitives`, `Kernel` (DurableStore), `RecordCodec`, `Encoding`, `FR08HandoffGate`, `TransitionPlan`, `ProtectedVerifier` | The list grows by seven. See the rebind procedure below |
| **Rule 3 role sites** | `@role_sites`: `{ProtectedPrimitives, {:@, :dimensions}}`, `{…, {:def, :persist_nonstart_settlement}}` (token at 203), `{…, {:defp, :required_dimension}}` | Three keys are renamed, each in the commit that moves its function: C2 gives `{Protected.Guards, {:@, :dimensions}}` and `{Protected.Guards, {:def, :required_dimension}}`; C6 gives `{Protected.Operations, {:def, :persist_nonstart_settlement}}`. The count stays at 4 and never reaches 5. The review found this acceptable |
| **Reopen-ready** (every committed state reopens `:ready`) | Writer and checker must agree. Proved by `reopen_property_test.exs` and the `*_restart_probe_test.exs` files | The writer (`Operations`) and the checkers (`RestartCheck`, `TransitionReplay`) are in different files. Each new file opens with a header comment naming its pair. Run the property test at every move commit |

**FR-08A rebind procedure.** This follows the gateway note's §3. Rule 5 requires the pin
list to grow; otherwise about 7,700 lines would be unpinned. The steps are for the lead,
on the integrated tip after C8. The developer only proves FR-08A red in a scratch worktree
and never commits a rebind.

1. Add seven tuples to `@api_identity`, one per `Protected.*` module, each with **two
   distinct placeholders**, 14 in total, of the form `"pin-sha256-<module>-end"` and
   `"pin-md5-<module>-end"`. The module is written `rows`, `guards`, `readset`, `reads`,
   `transitionreplay`, `operations` or `restartcheck`. The `-end` suffix is what keeps
   `pin-sha256-reads-end` from being a substring of `pin-sha256-readset-end`. No
   placeholder may be a substring of another or of any other text in the provider or
   test. This matters because `bin/rebind_fr08a.exs:30–49` rewrites values with
   `String.replace/3` over both files, so a shared placeholder would receive the first
   module's sha everywhere. Also change `fr08a_protected_boundary_test.exs:12`
   `length(...) == N` to the new count. If the gateway split has already landed (+3) the
   count is 20, or 19 if ML-DEAD-ROUTES has removed `ProtectedVerifier`. If this split
   lands alone, it is 17 or 16.
2. **Commit** those two files. The script refuses a dirty tree (17–18) and binds the
   subject to `HEAD`.
3. Run `MIX_ENV=test mix run --no-start bin/rebind_fr08a.exs`. Its output prints only 8
   characters per value, so it cannot show which placeholders were replaced. Check
   instead that `grep -c 'pin-' lib/foundry/repair/fr08a_protected_boundary.ex
   test/foundry/repair/fr08a_protected_boundary_test.exs` prints 0 for both files. It
   prints 0 at base, so no existing text collides with a placeholder.
4. Regenerate `docs/fr-08/fr08a-protected-report.txt` **in a fresh VM**, with the command
   the script prints, so that the rewritten provider is the one loaded.
5. Run `TMPDIR=/private/tmp MIX_ENV=test mix test
   test/foundry/repair/fr08a_protected_boundary_test.exs`. It must be green and the report
   must say `ready=true`. Then commit the provider, the test and the report as the rebind
   commit.

**Default for the rebind's timing.** The rebind comes last, on the integrated tip,
fast-forwarded so that `@subject_revision` stays the tip. That follows practice
(`8f7a049`, the script's header). It conflicts with the text of the repair plan's FR-23
acceptance ("same commit … never in a follow-up", REPAIR-PLAN.md:1643). The plan-text
amendment is routed to the operator (Q2).

## 4. Commit sequence

**Order across splits: the gateway split lands first,** as its note proposes. It is
smaller and proves the move checker on 2.4k lines before the checker meets 8k. It changes
no line of this file under its default for S2. **ML-DEAD-ROUTES lands before both** (§5).
There is one rebind per landed split, run serially (gateway seam S5).

**Planned tooling (operator note).** A later ticket, ML-PRECISION-TOOLING, is planned to
land before this split. It would add four things:
- the `boundary` library, under which rule 13 may become a compile-time boundary; the
  ExUnit reference-scan version stays as the spec either way;
- a Sourceror-based move task;
- the shared debug_info checker;
- an xref-graph test that compares the actual `Protected.*` dependency edges with §2's
  allowed-edge list.

If it lands, C0 and C1 use its tools, and this design's module boundaries, edge list and
invariants are unchanged.

**Move check: one shared checker.** The gateway split commits the checker (its M-series,
§4 of that note). This split reuses it and extends it only through configuration. The
checker compares **compiled definitions, not source AST**:
1. Build base and candidate in scratch worktrees with `MIX_ENV=test mix compile`.
2. For every module in the split set, read the `:debug_info` chunk through
   `:beam_lib.chunks/2`. Then call `backend.debug_info(:elixir_v1, mod, data, [])` to get
   `definitions`. In that form, aliases and imports are expanded to full module atoms,
   attributes are inlined and `__MODULE__` is substituted.
3. Normalise: strip meta, map `defp` → `def`, and rewrite a remote call to a module in the
   split set (the facade plus the seven `Protected.*` modules) into a local call.
4. Assert that the candidate's multiset of definitions equals the base's plus exactly the
   declared additions. Here those are the 7 facade delegates and the 3 accessors
   (`Rows.operation_types/0`, `Rows.closed_effect_statuses/0`, `Guards.dimensions/0`).
5. **Alias and import lint** (source level, from review 1). Every new file's
   `alias`/`import`/`require` lines must be a subset of
   `alias Foundry.DurableStore.{Database, Encoding, TransitionPlan}` plus `import` of
   `Foundry.DurableStore.Protected.*`. No `as:` and no `__MODULE__` are allowed. The one
   fully qualified outside call (`Foundry.DurableStore.Gateway.atomic_domain_request/1`)
   moves as written.

Step 3 is what makes resolution visible. A wrong alias, such as `Foundry.ManualLane.Replay`,
would expand to a remote call outside the split set, so it would not be rewritten to a
local call and the definitions would differ. Step 5 is defence in depth, and it catches
the mistake before compiling.

The checker prints its own per-module definition counts and the list of former `defp`s
that became `def`. Those printed numbers are authoritative, not the hand counts here.
Also keep the grep counts from §3: `Database.transaction` = 3, the 11 tag sites, the
refusal set and `System.halt` = 1. The reviewer's second view is
`git diff --color-moved=plain --color-moved-ws=allow-indentation-change`; `mix format` may
reflow a head that `defp` → `def` shortens.

Each move extracts one module from the facade, lowest layer first, so no step creates a
cycle. Moved bodies keep unqualified calls through `import`, and no name clashes are
possible because all names come from one file. The review found 0 of 335 names colliding
with `Kernel`.

| # | Commit | Moves (fns / clause lines) | Other edits | Focused tests beyond S |
|---|---|---|---|---|
| C0 | Configure the shared checker for this split, if it needs a config file | — | a split-set list and the declared additions | its red control: flip one atom in a moved body and the check fails |
| C1 | Extract `Protected.Rows` and add gate rule 13 | 66 / 920 | 2 accessors; a rule 13 test with `@protected_sites` (the one pin-provider exception) plus red control (~15 lines); BOUNDARY-RULES and AGENTS.md sentence | everything, since every layer uses Rows |
| C2 | Extract `Protected.Guards` | 28 / 432 | `dimensions/0`; 2 `@role_sites` keys | `live_refusal_probe`, `create_effect_refusal`, `review_independence`, `atomic_bundle` (discriminator) |
| C3 | Extract `Protected.ReadSet` | 25 / 592 | — | `decide_e2e`, `atomic_bundle`, `manual_lane` |
| C4 | Extract `Protected.Reads` | 51 / 1,077 | — | `observations_test`, `atomic_bundle` (corrupt page), `manual_lane` (log) |
| C5 | Extract `Protected.TransitionReplay` | 49 / 1,055 | — | `reopen_property`, the `*_restart_probe` tests |
| C6 | Extract `Protected.Operations` | 32 / 1,636 | 1 `@role_sites` key | `live_refusal_probe`, `quarantine_exit_probe`, `reopen_property` |
| C7 | Extract `Protected.RestartCheck` | 68 / 1,598 | The facade is now 16 fns / 419 lines plus 7 delegates | `authority_test`, `atomic_bundle`, `reopen_property`, all restart probes |
| C8 | Update citations | — | The [workflow contract](../WORKFLOW-CONTRACT.md) matrix rows and lines 676–706; comments at `transition_plan.ex:35` (a pinned file, covered by the same rebind) and `work_packet.ex:240`; the spec READMEs | `elixir bin/check_docs.exs` |
| C9–C10 | Lead: pin list with placeholders, then the rebind (§3) | — | provider, test, report | `fr08a_protected_boundary_test` green, `ready=true` |

**S** runs at every commit:
`test/foundry/durable_store test/foundry/architecture_boundary_test.exs
test/foundry/workflow/decide_e2e_test.exs test/foundry/manual_lane
test/foundry/observations_test.exs`. Then run `mix compile --force --warnings-as-errors`,
`mix format --check-formatted` and the move check against `e74fb88` or the rebased base.
The only expected failure in C1–C8 is
`test/foundry/repair/fr08a_protected_boundary_test.exs`. It is the only test that reads
FR-08A identity; the negative fixture expects `mismatch` anyway. The full gate runs once,
on the tip after the rebind.

**API tidy-ups are deferred.** Each changes pinned bytes, so each needs its own rebind:
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
| `transact_verified` + `ProtectedVerifier` | This module does not call `ProtectedVerifier`. Its only link to the route is `authority_mode/1`, called at `gateway.ex:215`. The legacy tables it counts (`claims`, `reservations`, `ledger_generations`, `receipts`, `leases`) are written only by that route (`gateway.ex:1837–1872`). The design is unchanged: `authority_mode/1` stays in `Reads`, whether or not ML-DEAD-ROUTES simplifies it. The pin count drops by one (§3). |
| `Foundry.Observations` | `effect_observation_page` stays, because `manual_lane/log.ex:18,105` still consumes it. `observations_test.exs` drops out of S. The `Foundry.Observations.Query` name collision disappears, but the rename to `Reads` stands. |

ML-DEAD-ROUTES lands first. If it edits this file (`authority_mode/1` 554–568,
`snapshot/2` 660), the assignment is by name and does not change. Re-run the move check
against the new base; do not rebase move commits by hand.

**Gateway design** (ML-DECOMPOSE-GATEWAY, its §6 seams S1–S5). Both keep the facade names
in §1 until T1.

| Seam | This file | `gateway.ex` |
|---|---|---|
| S1: Gateway → facade calls | the 12 names stay on `ProtectedPrimitives` | call sites unchanged in `Gateway`, `DomainCommit` and `AtomicBundle` |
| S2: `atomic_domain_request/1` back-edge | `RestartCheck` (6048) calls `Gateway.atomic_domain_request/1` | its default keeps a `Gateway` delegate to `AtomicBundle`, so this needs no edit. Under its Q2 alternative (move to `RecordCodec`), 6048 changes by one line in whichever split lands second |
| S3: `inject/2` vocabulary | facade 737–739 | 2047–2054. Both stay; this split owns any future merge |
| `atomic-bundle-v2` digest | reader `RestartCheck` (5571, 5615) | writer 592 |
| Command-id namespace (`commands` ⟷ `root_commands`) | `existing_command/4` and `validate_public_command_identity/2` read `commands` | 1911 reads `root_commands` via `root_command_id_exists?/2` |
| S5: rebind | one rebind for this split | one for the gateway split, run serially |

## 6. Quint and other citations

[`spec/ledger/ledger.qnt`](../../spec/ledger/ledger.qnt) cites `PP:<line>` 51 times, at
Pramāṇa `df1ac5f8`. These are already stale at `e74fb88`; for example `conserved?`'s
`PP:3019` is now at 3120. After the split a line needs a file as well. The recommendation
is to cite `Module.function/arity`, which survives moves and line drift, and to cite an
`apply_operation/2` clause as `Operations.apply_operation/2 "reserve"`. Every existing
citation already names its function, so the rewrite is mechanical:

| Target | ledger.qnt functions cited |
|---|---|
| `Rows` | `conserved?`, `current_generation`, `subtree_ledgers`, `reservations_for_effect/claim`, `settlement_proof`, `@closed_effect_statuses` (PP:8) |
| `Guards` | `reservations_open?`, `release_guard`, `load_effect_reservations`, `reservation_dimensions`, `attempt_open` |
| `Operations` | every `apply_operation` clause; `release_hold`, `close_subtree`, `revoke_unissued_generation`, `cancel_unissued_effect_owners`, `activate_reservations`, `release_many`, `settle_reservations`, `reservation_settlement`, `settle_with_receipts`, `reconciled_settlement`, `first_settlement`, `quarantine_conflicting_receipt`, `observation_conflict?` |
| `RestartCheck` | `validate_effect_relations`, `validate_ledger_tree`, `validate_reservations` |

The same applies to `spec/fr10/effects.qnt` (40 citations, at `33395c92`),
`spec/core_boundary/core.qnt` (28) and the three spec READMEs (6, 6, 4). This is batch C3
in the [dogfood log](../batch-d/DOGFOOD-LOG.md). Do it once, after C7. Dated records that
cite old lines are evidence and are not rewritten.

## 7. Risks and open questions (recorded, not decided)

| # | Risk | Mitigation |
|---|---|---|
| R1 | 85 former `defp`s become `def`, including the 12 `Rows` writers | Rule 13 (C1) fences them to the facade and `Protected.*`. All the modules are `@moduledoc false` |
| R2 | This is the most contended file (FR-10 commits 2–4 and ML-DEAD-ROUTES touch it) | Freeze edits to this file during C1–C7. Because the assignment is by name, redo the moves on a new base instead of resolving conflicts |
| R3 | `@x Owner.x()` creates compile-time dependencies | Only lower layers are referenced, so there is no compile deadlock. The facade owns no shared attribute |
| R4 | `import` hides where a call resolves | The debug-info check sees the resolution, the step 5 lint restricts aliases, and T3 can qualify calls later |
| R5 | The rebind's timing conflicts with the plan text | Default in §3; Q2 |

- **Q1.** Is the facade permanent, or does T1 follow in its own ticket with its own rebind?
- **Q2.** Should the repair plan's FR-23 acceptance text be amended to match practice (one
  rebind commit on the integrated tip), or should the series be squashed into one move
  commit plus its rebind?
- **Q3.** Should the pin list grow to named modules (proposed), or should the
  `protected/` directory be pinned as one identity? Either needs an edit to the provider.
- **Q4.** Should the shared move checker stay in `bin/` after both splits?
- **Q5.** Should `Operations` (1,636 lines) be split further? It cannot be split without
  first moving the reservation release and settle primitives below both halves.
- **Q6.** Namespace: `Protected.*` in a subdirectory (proposed), or flat `Protected*`
  files next to `protected_verifier.ex`?
