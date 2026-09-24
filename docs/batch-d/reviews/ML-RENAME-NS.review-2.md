approved

# Re-review: ML-RENAME-NS correction (candidate f4ca196 on base b30d0a2, prior ff0b5d5)
Reviewer: agent:claude-fable-5-1/review-ML-RENAME-NS-2. Worktree /private/tmp/review-ML-RENAME-NS-2 (detached at f4ca196, clean, untouched).

Correction delta `git diff ff0b5d5 f4ca196`: one commit, 3 files, +9/-9, all under docs/ (in packet scope). No lib/test/bin/config change.

## The three flagged sentences
- docs/REPAIR-PLAN.md:539 (live plan row): "rename the Pramāṇa-era `Pramana`-prefixed namespace to `Foundry`". Correct; names the from side.
- docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md:234: "the Pramāṇa-era `Pramana`-prefixed namespace, OTP app and `lib/`, `test/` directories → `Foundry`, `:foundry`, `lib/foundry/`, `test/foundry/`". Correct; matches what the candidate did (mix.exs `app: :foundry`, `releases: [foundry: ...]`, `lib/foundry`, `test/foundry`).
- docs/fr-23/FR-23-SPLIT-PROPOSAL-2026-09-22.md:164-165: "OTP app `:foundry`, modules `Foundry.*`, `lib/foundry/` and `test/foundry/`, each dropping its Pramāṇa-era `Pramana` prefix." Correct.

## Other lines the developer changed (all in CLEAN-ROOM-SWEEP)
- :46 "`.gitignore /foundry`" → "the `.gitignore` escript line". Accurate (.gitignore:8 is `/foundry`).
- :84 escript `foundry` (`ci.ex:385`, then `Pramana`-prefixed). Accurate in substance; the `ci.ex:385` line citation was already stale in base (the escript name lives at ci.ex:313,341,377,596,601 in both base and candidate). Pre-existing, not this ticket's.
- :109 "paths `lib/foundry/...`" → "its `lib/` paths". Accurate.
- :182 mix.exs "app, release and escript module, then `Pramana`-prefixed (renamed to `:foundry`, `foundry`, `Foundry.CLI`)". Accurate to the base doc (which said `PramanaFoundry.CLI`); actual escript main module is `Foundry.ManualLane.CLI` in both, a pre-existing doc imprecision.
- :183 .gitignore "the escript (then `Pramana`-prefixed, renamed to `/foundry`)". Accurate.

## Tautology sweep (excluding docs/archive/AUDIT-2026-09-12.md permalinks, exception a)
- Strict `X (→|->|to) X` with X any foundry-bearing token: 0 hits.
- Loose `foundry ... (→|->|to) ... foundry` within 25 chars in *.md: 2 hits, neither a rename description (CLOUDFLARE-OS.md:273 "asks Foundry to admit work ... Foundry-first"; FR08B-SUBCOMMIT2-DECIDE-DESIGN:219 "`objective` → `foundry.objective.v1`").
- No remaining ":foundry to :foundry", "foundry → foundry", or "lib/foundry → lib/foundry".

## Wording note (not blocking; finding for a later ticket if the operator wants it)
"`Pramana`-prefixed" contains the string "pramana" in a non-repository sense. Under the ticket's end goal (only references to the Pramāṇa repository survive) it is acceptable as a reference to the origin project (each is paired with "Pramāṇa-era"), and it is the honest record of what the old prefix was. Nit: the app/escript/.gitignore prefix was lowercase `pramana_` (`:pramana_foundry`, `/pramana_foundry`), so "`Pramana`-prefixed" is exact only for the module namespace. If a later sweep wants zero ASCII "pramana" outside repo links, "Pramāṇa-era prefix" (dropping the backticked token) reads fine everywhere; REPAIR-PLAN:539 alone could become "rename the Pramāṇa-era namespace to `Foundry`". Not a correction: the sentences are accurate now.

## Carried from review 1 (unchanged by this correction, not asked of it)
- Finding 2 (acceptance criterion 4, renamed build opens a copy of the lane store as ready) is still unreported in commit message or packet; code-path inference stands. Operator to state it at integration.
- Findings 3, 4 (info) unchanged.

## Checks run
- `git diff --stat ff0b5d5 f4ca196`: 3 files, +9/-9; `--name-only`: docs/REPAIR-PLAN.md, docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md, docs/fr-23/FR-23-SPLIT-PROPOSAL-2026-09-22.md.
- `elixir bin/check_docs.exs`: 0 broken links, exit 0.
- greps as above; `git status --short`: clean.
- Not run: ci/run.exs, full suite, compile (no code changed since the reviewed ff0b5d5).
