approved

Ticket: ML-CONTRACT-DIVERGENCES. Candidate 05e2f3c359e1c679386509f7ffe8cff28b2ad9ed on base 55037dbbdc84eef6105b218d585f855c5f63b123.
Reviewer: agent:claude-fable-5-1/review-ML-CONTRACT-DIVERGENCES (read-only; did not author the change).

## Scope

`git diff --stat 55037db 05e2f3c`: one file, docs/WORKFLOW-CONTRACT.md, +55/-0. Matches the packet scope exactly. Every cited source file is unchanged between base and candidate, so "at revision 55037db" is accurate.

## Truth of each divergence (read at 05e2f3c)

1. reserve moves no units.
   - lib/pramana_foundry/durable_store/protected_primitives.ex:1002 `apply_operation(conn, %{"type" => "reserve"})`: checks `"open" <- ledger.status`, `units <= ledger.available`, then inserts `status: "proposed"`; no `update_ledger`. Confirmed.
   - :1319 `activate_reservations(conn, reservations)` inside `create_effect` (clause starts :1221). Confirmed.
   - :3529-3549 `activate_reservations/2` moves `available - units`, `held + units` and re-checks `reservation.units <= ledger.available`. Confirmed.
   - Contract paraphrase matches the R5 row "absent → reserved | available→held, atomically with intent". Evidence anchor exists (spec/ledger/README.md:125).
2. Root reset grants fresh authority.
   - :1103-1148 root `reset_generation` (cited 1102; line 1102 is the blank line before `defp`, off by one, cosmetic). `units <= old.available`, `close_subtree`, fresh ledger `authorized: units, available: units`, `"transfer_kind" => "explicit_root_reset_unused_authority"` at :1148. Confirmed.
   - :1695-1716 `close_subtree`: `retired: current.retired + current.available, available: 0`; `authorized` untouched. `revoke_unissued_generation` (:1727) releases reserved holds and cancels their owners, does not touch authorized. Confirmed.
   - Contract paraphrase matches R5 "Such transfer decreases old authorized/retired and increases new authorized". "NoUnitsCreated still holds" is in the README.
3. return_allocation requires an idle child.
   - :956 clause; :973 `0 <- child.held`, :974 `0 <- child.delegated`; :998 `{:reject, :allocation_return_not_permitted, %{}}`. Confirmed.
   - Contract paraphrase matches R5 "Returning unused child available ... consumed/held cannot return".
4. Core has no paused control state.
   - :1841 (`active`), :1848 (`cancel_requested`), :1904-1905 fallback `{:error, :invalid_control_state}`; also :4434 `control["status"] in ~w(active cancel_requested)`. Confirmed.
   - :3462-3463 `control_active?/1` tests only `active`; called at :1376, :1443, :1498, :3272. Confirmed.
   - lib/pramana_foundry/workflow/kernel/state.ex:105-106 `"paused" => false, "draining" => false`. Confirmed.
   - lib/pramana_foundry/workflow/kernel/control.ex:8-21 `control_changed` (function actually runs to :23; cosmetic), :40-44 `require_not_paused`/`require_not_draining`, with the comment "Developer issue only". Confirmed.
   - R3 citation: WORKFLOW-CONTRACT.md:132-133 "For every effect claim the verifier independently checks: ... current control/policy revision". Confirmed. B3 anchor "Two facts found while answering, which the inventory did not record" exists at docs/fr-08/FR08B-B3-CONTRACT-READINGS-PROPOSAL-2026-09-22.md:26.

## Normativity

- The subsection opens with "They are facts, not contract changes: the text above keeps its meaning, and none of them decides whether the code or the contract should move." Each item ends in a question; none asserts a rule. No existing normative sentence was edited (diff is pure insertion).
- The R4 pointer ("Core has no pause or drain control state today; see known divergence 4") is descriptive and sits outside the tables. It does not alter the Control row.

## R4 parser

test/support/r4_rows.ex collects rows only after a line whose first cell is `From-state / input / guard` (WORKFLOW-CONTRACT.md:513) or the R4a header, and `collect/2` drops out of a table on the first non-`|` line. The pointer is a prose paragraph after the entity-state table (:440-442), which is never parsed. No risk. Test run confirms (below).

## Non-blocking notes (no correction needed)

- WORKFLOW-CONTRACT.md:701 links `#legal-lifecycle-and-controls--r4` (GitHub slug) while the document defines `<a id="r4">` at :424 and its only other in-document link uses an explicit id (`#enforcement-matrix`). `#r4` would be consistent and renderer-independent. bin/check_docs.exs does not verify fragments, so this is unchecked either way.
- Item 4 says pause/drain "exist only as the kernel reducer's ... flags". The legacy coordinator also carries a `paused` flag (lib/pramana_foundry/coordinator/state.ex:19,42,49; lib/pramana_foundry/scheduler/scheduler.ex:16). That coordinator is outside the v2 kernel/Core the contract governs and the acceptance criterion itself uses this wording, so it is not a defect of the candidate; a future edit could say "only as the kernel reducer's flags (and the legacy coordinator's)" if precision matters.
- Line cites 1102 (function starts 1103) and control.ex 8-21 (function ends 23) are off by one or two lines of whitespace/closing braces; the cited ranges still land on the described code.

## Checks run

- `git diff --stat 55037db 05e2f3c`: 1 file changed, 55 insertions(+), 0 deletions(-).
- `elixir bin/check_docs.exs` on a detached scratch worktree at 05e2f3c: `0 broken link(s)`, exit 0.
- `TMPDIR=/private/tmp MIX_ENV=test mix test test/pramana_foundry/workflow/r4_coverage_test.exs` on the same scratch worktree (deps/_build copied from the main checkout): 49 passed, 0 failures, 4.3 s; "R4/R4a outcome obligations: 124 - 72 asserted, 52 recorded uncited" (unchanged by this diff, which touches no R4 table cell).
- Scratch worktree removed afterwards; main checkout untouched (no edits, no commits).
