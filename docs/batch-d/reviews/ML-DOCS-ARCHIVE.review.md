approved

# ML-DOCS-ARCHIVE review — candidate 6761d1b4 on base 5fb76039

Reviewer: agent:claude-fable-5-1/review-ML-DOCS-ARCHIVE. Worktree /private/tmp/review-ML-DOCS-ARCHIVE.

## Checks run

- `git diff -M --name-status 5fb7603 HEAD`: 136 renames (111 R100, 25 with edits), 2 adds, 21 modifies, 0 deletes.
- Every changed line in the 25 edited renames (269 diff lines, `git diff -M base HEAD -- <old> <new>`) is a relative-link rebase; no prose changed. Same for the 12 modified unmoved docs (176 diff lines): links only.
- `git grep -F <each of 136 old paths>` over lib test bin ci spec mix.exs .github config rel: 0 hits. Only `docs/` path any executable still cites that was in scope is `docs/fr-04/identity-drift-probe.exs` (process_group.ex comment), and it stayed in place.
- `mix test r4_coverage_test schema_reference_test test/foundry/repair`: 75 passed, 0 failures (exit 0).
- `elixir bin/check_docs.exs`: 0 broken links (exit 0).
- Forbidden paths: docs/batch-d, docs/DURABLE-STORE.md, docs/CI.md untouched. docs/fr-08: six one-line link retargets (see below).

## Truth of the current docs (against code at HEAD)

- README.md: lane-only ingress matches `cli/rpc.ex:8,33,130` and `application.ex:17,49`; `pramana/<sha>` tags (2) exist. Layout omits `atomic_file.ex`, `observations.ex`, `schema.ex` — pre-existing, not in this diff.
- docs/OBSERVABILITY.md: `Log.trail/2` read-only (`log.ex:31`), `Log.operator/2` and `operator.log.jsonl` (`log.ex:176-182`), erlang.log path (LANE-RUNBOOK §6:181), `Observations` tested (`observations_test.exs`) and uncalled by manual_lane — all hold.
- docs/archive/README.md: FR-15aA "validator retired" holds (no `ci/validate_fr15aa.exs`); every link resolves.
- No current doc describes the daemon, Assessor or Relocation as live.

## Findings

1. **Router gap (minor, deferred):** `docs/DOGFOOD-READINESS-2026-09-23.md` is listed by sweep §3 as "current, keep at top level" and was routed from base `docs/README.md:31`; the new router drops it. It is still one hop away (REPAIR-PLAN:134, LANE-RUNBOOK:7, THIN-LANE-DESIGN:4). One row in docs/README.md fixes it; the sweep assigns README index work to ML-DOCS-CURRENT.
2. **fr-08 design files lost their router rows** (FR08B-B3-GAP-INVENTORY, plan-binding-specification, fr08b-ingress-inventory, …). Base docs/README.md linked ~28 fr-08 files; HEAD links only `fr-08/investigation.md`, which links 2. Most are reachable via REPAIR-PLAN/WORKFLOW-CONTRACT/the sweep; FR08B-B3-GAP-INVENTORY is reachable only by name in the sweep. Consistent with Q10 ("fr-08 untouched; triage in Batch C") and the router row says so. Note for the triage ticket.
3. **Six docs/fr-08 link edits — acceptable.** Criteria 1 (move fr-19a, IMPLEMENTATION-LOG, ALIGNMENT-AUDIT, ORCHESTRATOR-BOUNDARY per §3), 3a (0 broken links) and 3b (no fr-08 edit) cannot all hold: each of the four targets is a §3-listed move and each is linked from fr-08. The edits retarget one link each, change no prose, and were disclosed. Leaving the targets in place would have violated the sweep.
4. **Nothing current wrongly archived; nothing dated left beyond the disclosed keeps** except `fr-23/{FR-23-SPLIT-PROPOSAL,WORKTREE-INVENTORY}`, which §3 archives only "once acted on". `fr-18a/bounded-effect-query-design.md` → design/ matches §3. `docs/fr-04/identity-drift-probe.exs` stays (cited from code). fr-10 and orchestrator stay because their only citers are test comments outside scope, and both are routed.
5. `docs/archive/fr-15a/README.md` and `RELOCATION-RULES` (existing archive files) received link-only rebases; they did not move.

## Verdict

Approved. Deferred: add a DOGFOOD-READINESS row to docs/README.md (ML-DOCS-CURRENT); fr-08 router coverage returns with the Batch C triage.
