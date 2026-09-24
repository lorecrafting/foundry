correction

Ticket ML-DECOMPOSE-PP-DESIGN, review 2 (correction round). Candidate f5dbf47baa5cf013ba3603050c3344c648b4e7ca on base e74fb88 (first candidate 281e75c).
Reviewer agent:claude-fable-5-1/review-ML-DECOMPOSE-PP-DESIGN-2, detached worktree /private/tmp/review-ML-DECOMPOSE-PP-DESIGN-2.
Scope: `git diff --stat 281e75c f5dbf47` is one file, docs/design/DECOMPOSE-PROTECTED-PRIMITIVES.md (+197 −139), inside the packet scope. Worktree clean.

Review 1's three required fixes and the operator's two additions all landed and reproduce
(details under "Verified"). One new contradiction inside the design must be fixed before an
implementer follows it; it is a one-sentence change.

## Findings, by severity

### 1. (must fix) Rule 13 as written goes red on the design's own C9 pin commit

§3 row "Write path" (design:129) defines rule 13 as: in `lib/`, only
`Foundry.DurableStore.ProtectedPrimitives` and `Foundry.DurableStore.Protected.*` may
*reference* `Foundry.DurableStore.Protected.*`, using `references/2`
(test/foundry/architecture_boundary_test.exs:185). That scanner yields every `__aliases__`
node, including those inside a module-attribute value (walk clauses at :240–244 and
:256–257; the moduledoc at :7–10 says so: "a module attribute is a reference").

§3 step 1 (design:139) then has the lead add seven tuples naming
`Foundry.DurableStore.Protected.Rows` … `Protected.RestartCheck` to `@api_identity` in
`lib/foundry/repair/fr08a_protected_boundary.ex` (the tuple shape at provider:19–51 is
`{Module, path, sha, md5}`; bin/rebind_fr08a.exs:31–36 regex-finds the module name from
that tuple, so the module atom must be present). That file is in `lib/` and is neither the
facade nor `Protected.*`, so rule 13 flags seven references at the pin commit and the "full
gate once, on the tip after the rebind" (design:232–233) is red by construction. Also note
the pin provider is not exempt from the rule by any other path: the existing rules that
need exceptions declare sites (`@software_sites` at :30–33, `@role_sites` at :45–50).

Fix: in §3's rule 13 text and C1's "Other edits", declare the one exception the same way
rule 4 does: `{Foundry.Repair.FR08AProtectedBoundary, {:@, :api_identity}}` is the only
site outside the facade and `Protected.*` that may name a `Protected.*` module (it names,
never calls). Keep the red control as written. Then rule 13, C1 and C9 agree.

### 2. (should fix) Rebind step 3 asks for a check the script's output cannot give

§3 step 3 (design:153–154): "check that all 14 placeholders appear in its `old -> new`
output". bin/rebind_fr08a.exs:52 prints `String.slice(o, 0, 8) -> String.slice(n, 0, 8)`,
so every placeholder prints as `pin-sha2 -> …` or `pin-md5- -> …`; the 14 lines cannot be
told apart, only counted. Replace with a check that works against the script as it is:
after step 3, `grep -c 'pin-' lib/foundry/repair/fr08a_protected_boundary.ex
test/foundry/repair/fr08a_protected_boundary_test.exs` must print 0 for both (today it
does: 0 hits, so no pre-existing text collides). The gateway note's step 3 (its :136–137)
has the same wording; the fix there is the operator's call, not this ticket's. Also, the
dirty-tree refusal is at script lines 17–18, not 16–17 (design:151; the gateway note
copies the same off-by-one).

### Notes (no change required)

- Placeholders (§3 step 1): checked mechanically. The 14 `pin-{sha256,md5}-<m>-end` values
  have 0 substring pairs among themselves and 0 against the gateway note's six
  (`pin-sha256-domaincommit` etc.). Without `-end`, `pin-sha256-reads` ⊂
  `pin-sha256-readset` and likewise for md5, so the suffix is load-bearing as the design
  says. The script replaces each `{old, new}` pair with `String.replace/3` over the whole
  provider and test (:45–50), builds pairs from `identity().exercised_api` (:28–41), and
  hashes `File.read!(path)`, so each new tuple's path must be the real
  `lib/foundry/durable_store/protected/<file>.ex`; a wrong path raises rather than
  mis-rebinding. Procedure otherwise matches the code.
- Pin arithmetic: base 10 (provider:19–51, test:12 `== 10`); gateway +3 → 13; this +7 →
  20; ML-DEAD-ROUTES (approved) removes `ProtectedVerifier` → 19. "Lands alone: 17 or 16"
  is also right. Consistent with the gateway note (:119–120, :162).
- Fold: RestartCheck = 68 groups (41 + 27); module edges after the fold are exactly
  `restart -> guards, replay, rows` (review 1 had `restart -> bundle` and
  `bundle -> guards, rows`, both absorbed); no new edge, no cycle. The 6048 back-edge to
  `Gateway.atomic_domain_request/1` sits in the folded run (5498–6282) and is the
  pre-existing PP ↔ Gateway cycle the gateway note names (its :68–69, S2); it is a fully
  qualified remote call, so the move check's step 3 leaves it remote on both sides.
- Module names: `grep defmodule` over lib, test, bin, ci finds only
  `Foundry.Observations.Query` and `Foundry.ManualLane.Replay` with a matching last segment;
  none for Rows, Guards, ReadSet, Reads, TransitionReplay, Operations, RestartCheck, or a
  bare `Protected`. No `Foundry.DurableStore.Protected.*` reference exists in lib today (0).
  The gateway note's Q1 *alternative* would create `Foundry.DurableStore.Operations`, a
  last-segment match with `Protected.Operations`; harmless under both designs' rules
  (imports only, no `alias`), but worth one line if that alternative is ever taken.
- Rule 13 does not misfire on `ProtectedPrimitives` or `ProtectedVerifier`: `under?/2`
  (:181) compares whole segments, so `ProtectedPrimitives` ≠ `Protected`.
- Gateway consistency: landing order (ML-DEAD-ROUTES, gateway, this) matches its §5–§6;
  S1 facade names, S2 default (Gateway delegate, zero edits here), S3 left alone, S5 one
  rebind per split run serially — all consistent. The gateway note proposes no rule of
  its own, so "rule 13" is unambiguous.
- §2 "Every reference between split modules is written `Foundry.DurableStore.Protected.X`"
  and §4 "moved bodies keep unqualified calls through `import`" read as contradictory
  until one sees that the first means the `import` lines and attribute consumers. A nit.
- Rule 3: `required_dimension/2` must become `def` (only cross-module caller is
  `RestartCheck.validate_effect_authority_relations/1`, reproduced), matching the C2 key
  `{Protected.Guards, {:def, :required_dimension}}`.
- New citations in the delta hold: gateway.ex:666 is `Database.transaction`, PP:5665 is
  `TransitionPlan.bind`, PP:6048 is the fully qualified Gateway call, WORKFLOW-CONTRACT
  rows 178–188 and lines 676–706 cite `protected_primitives.ex`, work_packet.ex:240 and
  transition_plan.ex:35 are comments naming `ProtectedPrimitives`, REPAIR-PLAN.md:1643 is
  the "same commit" sentence, AGENTS.md:12 says "twelve rules" and BOUNDARY-RULES.md
  numbers 1–12.

## Verified (commands and counts)

- `git diff --stat 281e75c f5dbf47`: 1 file, +197 −139. `git diff --stat e74fb88 f5dbf47`:
  1 file, +310. `git diff --exit-code`: clean at f5dbf47.
- Review 1's throwaway `callgraph.exs` rerun as `callgraph2.exs` (scratchpad, outside the
  repo) with the revised runs: Rows 2677–2682, 2786–3134, 3707–3708; BundleCheck folded
  into `restart: [{668,700},{5340,6669},{7779,8113}]`. Output: 539 clauses, 335 groups;
  0 unassigned, 0 in two modules, **0 clauses whose last line is outside its run** (review
  1 had 3); per-module groups facade 16, rows 66, guards 28, readset 25, operations 32,
  query(Reads) 51, replay 49, restart 68 — all equal to §2; edges exactly
  `guards,readset,query,replay,facade -> rows`, `operations -> guards,rows`,
  `restart -> guards,replay,rows`, `facade -> operations,readset`; cycle? false.
  Cross-module calls to current `defp`s: 85 (rows 60, guards 19, readset 3, replay 2,
  operations 1), matching R1's "85" and each module's "N former defps".
- Spot-check of 5 corrected runs against the file: 2677–2682 (`request_digest/2` ends at
  the `})` on 2682), 3120–3134 (`conserved?/1` ends at `)` on 3134), 3707–3708
  (`assignment_id/3`, 2-line `do:`), 3136 alone (`ledger_key/2`, ReadSet), and the folded
  5340–6669 run: `validate_atomic_bundle_rows/1` 5498–5519, `validate_attempt_closures/1`
  5522–5544, `validate_bundles/2` starts 5546, `validate_inboxes/1` starts 6284, run ends
  6669; TransitionReplay 6671–7777; 7779 starts the next RestartCheck run; 8115 `encode/1`
  starts the Rows tail.
- Placeholder check: `elixir -e` over the 14 + 6 strings: 0 substring pairs; without
  `-end` 2 pairs (reads ⊂ readset). `grep -c 'pin-'` provider, test, negative fixture: 0, 0, 0.
- `elixir bin/check_docs.exs` at f5dbf47: 0 broken links.
- Read in full: test/foundry/architecture_boundary_test.exs (293 lines),
  bin/rebind_fr08a.exs (57), lib/foundry/repair/fr08a_protected_boundary.ex (648),
  test/foundry/repair/fr08a_protected_boundary_test.exs, /private/tmp/DECOMPOSE-GATEWAY-corrected.md (256).
- No tests run (design-only change; standing rules: focused tests only, none applicable).
