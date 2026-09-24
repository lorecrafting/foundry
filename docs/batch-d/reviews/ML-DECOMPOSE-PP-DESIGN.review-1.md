correction

Ticket ML-DECOMPOSE-PP-DESIGN. Candidate 281e75c65f9ddec168a43e08b6724f1f92c44331 on base e74fb88.
Reviewer agent:claude-fable-5-1/review-ML-DECOMPOSE-PP-DESIGN, detached worktree /private/tmp/review-ML-DECOMPOSE-PP-DESIGN.
Scope: the diff is one added file, docs/design/DECOMPOSE-PROTECTED-PRIMITIVES.md (+252), inside the packet scope. Nothing else changed.

The design is sound and its measurements reproduce (see "Verified" below). Three fixes before an
implementer can follow it safely; the first is the one that matters.

## Findings, by severity

### 1. (must fix) The split publishes the store's write primitives and leaves the guard as an open question (Q6, R1)

Today the only way to write a `root_*` row is through the 12 public functions, because every
insert/update is `defp` (protected_primitives.ex:2786–4316). After C1, `Protected.Rows` exports
`insert_claim/2 insert_effect/2 insert_ledger/2 insert_receipt/2 insert_reservation/2
insert_simple_history/7 update_claim/3 update_effect/3 update_ledger/3 update_reservation/3
write_inbox_head/5 write_simple/7` (12 writers, measured: every one is called cross-module from
`Operations`). `lib/foundry/manual_lane/log.ex:14` and `replay.ex:12` already alias
`Foundry.DurableStore.*`; nothing in the gate stops any `lib/` module outside `durable_store/`
from calling `Rows.update_ledger/3` and bypassing every guard in `Guards`/`Operations`. That is
a boundary-rule-7-class regression ("a guarantee Core owns never depends on a controller
checking it") introduced by construction, and the design records it only as R1/Q6.

Fix: make Q6 a decision, not a question. Add to §3 an invariant row "Write path: only the
command pipeline reaches `root_*` writes", and add to C1 (the commit that creates `Rows`) a
gate rule in test/foundry/architecture_boundary_test.exs: only
`Foundry.DurableStore.ProtectedPrimitives` and `Foundry.DurableStore.Protected.*` may
reference `Foundry.DurableStore.Protected.*` (the existing `references/2` scanner at
architecture_boundary_test.exs:184 plus a red-control fixture, ~10 lines), and the matching
sentence in docs/BOUNDARY-RULES.md. Test files stay exempt (restart probes may want to write
corrupt rows directly).

### 2. (must fix) C0 cannot see alias resolution; add an allowlist rule

The checker compares bodies AST-equal after stripping metadata. A body such as
`Encoding.semantic_digest(...)` (2679, 4091, …) has the same AST whatever `alias` line sits
above it, so a wrong or missing alias is invisible to C0. `--warnings-as-errors` catches a
missing alias (undefined module) but not a wrong one that exists. Two real collisions exist
already: `Foundry.ManualLane.Replay` and `Foundry.Observations.Query` share last segments with
the new `Protected.Replay` and `Protected.Query`; `alias Foundry.ManualLane.Replay` in
`RestartCheck` would compile and dispatch elsewhere. (There is no `__MODULE__`, macro,
`Logger`, `raise`, struct, or module-name string in the file today — grep — so aliases are the
only resolution hazard, and there is exactly one alias line, :4.)

Fix: C0 rule 5: every NEW file's `alias`/`import`/`require` lines must be exactly
`alias Foundry.DurableStore.{Database, Encoding, TransitionPlan}` (any subset) plus
`import`/`alias` of `Foundry.DurableStore.Protected.*`, with no `as:`; and NEW files contain no
`__MODULE__`. Ten lines in the checker; keeps R4/T3 honest.

### 3. (should fix) Three line runs in §2 cut a clause mid-body; two counts are off by one

Rebuilt from `Code.string_to_quoted` and the design's own runs: `request_digest/2` is
2677–2681 (run says `2677`), `conserved?/1` is 3120–3133 (run ends 3120), `assignment_id/3` is
3707–3708 (run says `3707`). Harmless for the implementer (assignment is by name/arity, and
the C0 checker rechecks) but the table is the reviewer's spot-check tool, so fix the runs.
Guards: 19 former `defp`s are called cross-module (design: 20); total 86 (design: 87). Ship the
checker's own counts in C0's output rather than hand numbers.

### Notes (no change required)

- Q2 (rule 3 renames): acceptable. Count stays 4; each rename lands in the commit that moves
  the function (C2: `{:@, :dimensions}` and `{:def, :required_dimension}`; C7:
  `persist_nonstart_settlement`), so the list never has five entries. `required_dimension/2`
  must be `def`: its only cross-module caller is `RestartCheck.validate_effect_authority_relations/1`.
  The consumer form `@dimensions Guards.dimensions()` yields no role token to the scanner
  (architecture_boundary_test.exs:205–216 walks the value; an `__aliases__` node is not a literal).
- Q3 (rebind): the plan's rule (docs/REPAIR-PLAN.md:1643 "same commit … never in a follow-up")
  and practice (bin/rebind_fr08a.exs:5–7 requires a committed subject and a separate rebind
  commit; 8f7a049) do conflict; the question is posed clearly. The claim "the only test that
  reads FR-08A identity" holds: the only other reader is test/support/fr08a_identity_negative_fixture.exs:19–20,
  which expects `mismatch`. Suggest the design name a default (practice: rebind as C10 on the
  integrated tip, fast-forward so `@subject_revision` stays the tip) and route the plan-text
  amendment to the operator.
- Q4 (pin 18 modules): correct that bin/rebind_fr08a.exs:27–40 only rewrites values present in
  `identity().exercised_api`; distinct per-entry placeholders would also work, but real hashes
  are simpler. `length(...) == 10` is at fr08a_protected_boundary_test.exs:12.
- Q5/Q7 granularity: 8 is defensible; every module's edges are the ones the design draws. The
  one seam I would close: `BundleCheck` (27 fns/692 lines) into `RestartCheck`. Its only caller
  is `RestartCheck.validate/1`, it adds no edge (`RestartCheck` already depends on `Guards` and
  `Rows`), and the reopen-ready pair would then be "Operations ↔ RestartCheck + Replay" rather
  than three checker files. Keep `Replay` separate (a self-contained re-execution algorithm,
  Rows-only). Not a blocker.
- `@dimensions` is read at 874 (Operations) and 6346 (RestartCheck) and nowhere in Guards'
  ranges; §2 places it in Guards for role-site co-location, which is fine, but the Rows row
  ("holds … the shared vocabulary attributes") should not claim it.
- Invariants list (§3) is otherwise complete against the file: 7 tags at 11 sites (776, 1250,
  2679, 4091, 4375, 4379, 5571, 5615, 6323, 6554, 7983); 3 transaction sites (358, 393, 4320);
  fault points 36, 424, 737–739 (`System.halt(71)`); 43 distinct `{:reject, atom, _}` + 1
  `{:quarantine, :conflicting_receipt, _}`.
- C9 citation inventory: dated records (docs/fr-10, docs/orchestrator, docs/fr-23,
  docs/design/bounded-effect-query-design.md) cite old lines and are rightly left alone.

## Verified (commands and counts)

- `git diff --stat e74fb88..HEAD`: 1 file, +252. `git status --short`: clean.
- Throwaway `elixir callgraph.exs` (scratchpad, outside the repo; parses the file with
  `Code.string_to_quoted`, groups def/defp by name/arity incl. `&f/n` captures, assigns by the
  design's §2 line runs): 539 clauses, 335 groups; 0 unassigned, 0 assigned to two modules;
  per-module counts facade 16, Rows 66, Guards 28, ReadSet 25, Operations 32, Query 51,
  Replay 49, BundleCheck 27, RestartCheck 41 (all equal to §2); module edges exactly
  `Guards,ReadSet,Query,Replay,BundleCheck,Operations,RestartCheck,facade -> Rows`,
  `Operations,BundleCheck,RestartCheck -> Guards`, `RestartCheck -> BundleCheck,Replay`,
  `facade -> ReadSet,Operations`; DFS: no cycle. Function-level edges out of and into
  Guards/ReadSet/Replay listed (Rows-only outward; inward from Operations, facade,
  BundleCheck, RestartCheck as the design says).
- `elixir kernel_clash.exs`: 0 of 335 names collide with `Kernel` exports (import-safe).
- grep: attributes defined :6–15, reads at 18/439/2645/2182, 1609/6830, 1611, 874/6346,
  4328–5166 — all inside the owning/consuming modules the §2 table names.
- grep `__MODULE__|__ENV__|Logger|raise|defmacro|quote|%Struct{`: 0 hits; one `alias` line (:4).
- grep `PP:` line counts: ledger.qnt 42 lines, effects.qnt 30, core.qnt 25 (design counts
  citations, several per line; plausible, not recounted).
- No tests run (design-only change; standing rules: focused tests only, none applicable).
