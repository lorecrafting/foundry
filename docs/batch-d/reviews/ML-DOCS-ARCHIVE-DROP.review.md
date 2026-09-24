approved

# ML-DOCS-ARCHIVE-DROP review

Reviewer: agent:claude-fable-5-1/review-ML-DOCS-ARCHIVE-DROP. Candidate `29185be`, base `ecdbc84`,
worktree /private/tmp/review-ML-DOCS-ARCHIVE-DROP. Read-only review; no edits, no gate, no full suite.

## Verdict: approved

## 1. Permalinks resolve at the tag

- Tag `records/2026-09-24` is on origin (`git ls-remote`), tag object `e509dc2` -> commit `b30d0a2`,
  which is an ancestor of base `ecdbc84`.
- 67 occurrences of `https://github.com/lorecrafting/foundry/(blob|tree)/records/2026-09-24/` in
  the tree (matches the ticket's "67 links in 13 files"); 41 unique URLs (40 blob, 1 tree).
- Every URL verified with `git cat-file -t records/2026-09-24:<path>`: 0 missing, and the object
  kind matches the URL form (blob URLs are blobs, the one tree URL `docs/archive` is a tree).
- Anchor: the only anchored URL (`fr-18a/independent-review.md#b5--the-declared-public-bounds-...`)
  matches heading `## B5 — The declared public bounds sit after an unbounded protected materialization`
  at line 120 of the tagged file.

## 2. No live reference into docs/archive

- `elixir bin/check_docs.exs` -> `0 broken link(s)`.
- `grep -rn docs/archive` over the whole tree (excluding .git/_build/deps), minus permalinks: hits only
  in dated records — `docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md`, `docs/batch-d/DOGFOOD-LOG.md`,
  `docs/batch-d/reviews/*.md`. None in lib, test, bin, ci, .github, mix.exs. Also none at base
  (`git grep docs/archive ecdbc84 -- lib test bin ci`), so acceptance criterion 3 was vacuous.
- Every `docs/...` path literal in lib/test/bin/ci resolves in the candidate tree (fr-08 probes,
  `fr08a-protected-report.txt`, WORKFLOW-CONTRACT, BOUNDARY-RULES, DURABLE-STORE-SCHEMA, ...).
- Bare prose paths in live docs (info, not blocking, both pre-existing at base):
  - `docs/WORKFLOW-CONTRACT.md:52` "Run `python3 docs/fr-06/storage_spike.py`" — the script is now
    only at the tag; this path was already wrong before this change (it moved to archive in
    ML-DOCS-ARCHIVE). Cheap to fix in a later doc pass.
  - `docs/REPAIR-PLAN.md:1762` "retained in `docs/fr-04/`" — the FR-04 review chain is at the tag;
    live `docs/fr-04/` holds only the identity-drift probe. Pre-existing.
  - `IMPLEMENTATION-LOG` is mentioned by name (no path) in EVIDENCE-TOOLS, COVERAGE-GUIDED-SWEEP,
    REPAIR-PLAN:994, DOGFOOD-READINESS; the docs/README.md row "the implementation log" routes to
    the tag, so a reader can find it.

## 3. Nothing still-current was deleted

- Deleted set (138 paths) is exactly `git ls-tree -r --name-only records/2026-09-24 docs/archive`.
- Skimmed the listing and the archive README at the tag. Non-Markdown files are probes, manifests
  and spike outputs (audit-2026-09-12/probes.exs, fr-06 storage spike, fr-09 pi_rpc_probe, fr-15a
  validator + retired test as .txt, fr-18a probes): none cited from lib/test/bin/ci.
- `docs/fr-04/identity-drift-probe.exs`, cited from `lib/foundry/effects/process_group.ex:190`, is
  in live `docs/fr-04/` and untouched (the archive README said it stays there; confirmed).
- Retired-mechanism docs (ASSESSOR, EVENT_SOURCING, MIGRATION, MIGRATION-TICKETS, old OBSERVABILITY)
  and RELOCATION-RULES-2026-09-23 are dated records; the live docs that cite them (STRATEGY,
  OBSERVABILITY, DURABLE-STORE) describe them as archived design input, now via permalink.
- `docs/fr-08` untouched except three link rewrites inside it (batch C triage unaffected); test-read
  fr-08 files all present.

## 4. Indexes

- `docs/README.md:30`: the "Anything dated" row now says "Not in the tree: tag `records/2026-09-24`"
  with a tree permalink. Reads correctly.
- `README.md:72-73`: audit permalink plus "every other dated record are archived (tag
  `records/2026-09-24`, docs/archive at the tag)". Tracked-layout list does not mention archive.

## 5. Scope

- 151 changed paths: 138 deletions under `docs/archive/`, 13 modifications
  (README.md, docs/{README,DURABLE-STORE,OBSERVABILITY,REPAIR-PLAN,STRATEGY,WORKFLOW-CONTRACT}.md,
  docs/design/bounded-effect-query-design.md, docs/fr-08/{3 files}, docs/fr-23/{2 files}).
  All inside packet scope [docs, README.md, AGENTS.md, lib, test, bin]; AGENTS.md/lib/test/bin unchanged.
- Diff of the 13 files read in full: every hunk is a relative link -> permalink rewrite or the two
  index sentences; no prose changed otherwise.

## Checks run

- `elixir bin/check_docs.exs`: 0 broken links.
- Permalink resolution script over 41 unique URLs: 0 missing, 0 kind mismatches.
- No ci/run.exs, no mix test (per brief).
