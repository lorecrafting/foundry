approved

# ML-RENAME-DOMAIN-TAGS review

Reviewer: agent:claude-fable-5-1/review-ML-RENAME-DOMAIN-TAGS (independent of developer agent:claude-opus-5-5).
Worktree: /private/tmp/review-ML-RENAME-DOMAIN-TAGS, candidate 1805695, base 6a13b7c. 27 files, +91/-51.

## Findings (ranked)

None blocking. Info only:

1. FR-08A red, expected until the operator's rebind (2 tests, test/foundry/repair/fr08a_protected_boundary_test.exs:6 and :35):
   `implementation_binding=mismatch:source-sha256+beam-md5/v1` (pinned hashes of gateway.ex,
   protected_primitives.ex, record_codec.ex, fr08_handoff_gate.ex predate this edit), and the frozen
   report docs/fr-08/fr08a-protected-report.txt still says `pramana-foundry-fr08a-protected-boundary/v1`
   and `pramana-foundry-fr07-fr08-handoff/v1`. `bin/rebind_fr08a.exs` regenerates both. docs/fr-08 is
   outside the allowlist grep by design (batch C triage). Every other test passed.
2. Nit, no action: docs/fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md:84 keeps a present-tense inventory row
   ("`ci.ex` carries names `pramana-foundry-ci-provenance/v2` (`ci.ex:9`)") that is now historical;
   §5.1 already lists the file as quoting retired names.
3. Nit, no action: docs/strategy/META-HARNESS.md:12,25,173 use unaccented "Pramana" for the project
   (moved doc); still a reference to the Pramāṇa project, which Q6 keeps.

## Checks

1. Tag consistency. `git grep -n -E 'semantic_digest\(|@schema |"domain" =>|<- map\["domain"\]|"schema" =>|schema: "' -- lib`:
   22 sites, all `foundry-*`. Writer/reader pairs: atomic-bundle-v2 (gateway:611 writes; protected_primitives:5571, :5615 verify),
   authenticated-inbox-item-v1 (pp:776 / pp:6323), effect-request-v1 (pp:1250 / pp:6554, record_codec:157 + 8 test/fixture sites),
   root-receipt-v1 (pp:4091 / pp:7983), command-v1 (gateway:1518 writes `"domain"` / record_codec:258 matches it),
   protected-command-v1, effect-observation-scope/source-v1, ci-provenance/v2, fr07-fr08-handoff/v1, fr08a-protected-boundary/v1,
   fr08a-receipt/v1 (single site each). Distinct `"foundry-*"` strings in lib+test: 12 tags + the pre-existing `foundry-rpc-wrapper-` prefix.
   `git grep -n pramana-foundry -- . ':!docs'` -> 0. Base had 37 `pramana` lines in lib test config bin rel ci spec;
   diff removes 34 (lib/test/config) + 1 (rel/overlays/env.sh:20), leaving the 2 allowed test lines. No non-rename code line
   in the diff except the digest pin.
2. Golden digest, recomputed with `shasum -a 256` (no Elixir):
   `{"domain":"foundry-command-v1","schema_version":1}` -> d194a1e3f7be1dfbd81e896b737b858568a39e1983d59253583499bcea81ea0b (matches
   review_corrections_test.exs:525); control `{"domain":"pramana-foundry-command-v1","schema_version":1}` -> a97024e2… (the old pin).
   Key order confirmed against encoding.ex normalize_pairs/sort; the control-escape assertion in the same test is unchanged.
3. Allowlist. `diff <(git grep -il pramana -- ':!docs/fr-08' | sort) <(table files | sort)` -> empty; 32 files.
   Every hit inspected (`git grep -in pramana` over the 32): github.com/lorecrafting/pramana links and permalinks at
   e1e4b3bf / 2ad8ed91, issues #47/#48, PR #49, `pramana/<sha>` tags, Pramāṇa checkout paths (WORKTREE-INVENTORY:31-34),
   DOGFOOD-LOG:37,38,56 and the five review records quoting retired names (Q10: reviews and the log stay),
   architecture_boundary_test.exs:53-54,133-135 (rule 6 umbrella guard), ci_test.exs:25 (`pramana.gate` refutation).
   DOGFOOD-READINESS:113 `bin/pramana-supervisor`: never in this repo (`git log --all -- bin/pramana-supervisor` empty,
   absent at records/2026-09-24), so it is Pramāṇa's script as the table says. No entry is un-renamed Foundry vocabulary.
   docs/fr-08 excluded: 22 files.
4. Residual lowercase. `git grep -n pramana -- lib test bin config rel ci spec mix.exs .gitignore mise.toml .github`:
   only the 2 allowed test lines. Case-insensitive over lib bin config rel ci spec mix.exs .gitignore mise.toml .github: 0.
5. Seed. lane-policy.example.json:10 `{"developer": 50, "reviewer": 50}`; LANE-RUNBOOK.md:43-44 says 50/50.
   Readers: bin/foundry-lane:20 and test/foundry/manual_lane/startup_test.exs:13 (loads it, asserts no count).
   Other tests seed their own 3/3 or 3/2 literals.
6. `mix compile --warnings-as-errors` exit 0; `mix format --check-formatted` exit 0; `elixir bin/check_docs.exs` 0 broken links.
   `mix test test/foundry/durable_store test/foundry/manual_lane test/foundry/ci_test.exs test/foundry/repair
   test/foundry/boundary_test.exs test/foundry/architecture_boundary_test.exs`: 395/397 passed, 2 failed (both FR-08A, finding 1;
   confirmed by `mix test --failed`). Lane admit/packet/submit/review ran ok in manual_lane tests against the 50/50 example policy.
   Not run: ci/run.exs, full suite, live store rotation (operator's).
7. Scope. Changed paths: README.md, config/, docs/, lib/, rel/, test/ — all inside the packet scope.
