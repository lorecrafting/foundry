correction

Reviewed: /private/tmp/foundry-front-door-review at a076625 (base b43dc0f, commits e30e780 and a076625). Read-only; nothing edited in the checkout.

## Findings

### F1 (high) docs/CONCEPTS.md:120-122 — `lane log` does not show the refusals the sentence names
"A refusal commits nothing to the ticket, and `lane log` still shows it" is false for all three examples given two lines earlier. `Log.trail/2` reads only `atomic_bundles`/`root_commands` rows with `disposition != 'accepted'` (lib/foundry/manual_lane/log.ex:25-28, 56-60), i.e. commands Core itself refused (`principal_not_independent`, `revision_conflict`, a lost CAS race). `wrong_source_phase` is a kernel `decide/3` reject returned before anything is submitted (lib/foundry/workflow/kernel/shared.ex:37; backend.ex `with {:ok, decision} <- WorkflowKernel.decide(...)` at lines 106-108 and 372-373 falls through on `{:reject, _}`), `candidate_mismatch` is raised in `Backend.frozen/3` (backend.ex:280) and `CLI.freeze/5` (cli.ex:392) before any write, and `git_evidence` in cli.ex:500 before Core is asked. Those reach only `operator.log.jsonl`.
Fix: "A refusal commits nothing. Refusals Core itself records (a reviewer refused for independence, a lost CAS race) appear in `lane log`; refusals made before Core is asked (`wrong_source_phase`, `candidate_mismatch`, `git_evidence`) appear only in the operator log." LANE-RUNBOOK.md:224 ("including refused commands") has the same ambiguity and could take the same qualifier.

### F2 (medium) README.md:47 — "uncertain outcomes are reconciled before any retry" overclaims
No reconciliation exists. FR-10 is Blocked (docs/REPAIR-PLAN.md:526); an `unknown` settlement is permanent, holds its units and abandons the ticket (docs/batch-d/LANE-RUNBOOK.md:145; CONCEPTS.md §6 says exactly this). Fix: "and an uncertain outcome is never retried: it is settled as `unknown` until FR-10 supplies reconciliation."

### F3 (medium) docs/CONCEPTS.md:92-93 — command identity is not derived from actor + request
Step 1 says the gateway "derives the command's identity from the actor and the complete canonical request". The identity is the caller-supplied `command_id` (gateway.ex:450 `normalized_command["command_id"]`; the lane derives it from state, backend.ex:14-15). What Core computes from actor + canonical request is a digest (gateway.ex:1419-1430), compared in `existing/4` (gateway.ex:1766-1783) to return the stored result or `idempotency_conflict`. Fix: "takes the command's id from the caller (the lane derives it from state, never a clock) and fingerprints the actor plus the complete canonical request; 2. returns the stored result if that id was committed with the same fingerprint, and reports a conflict if it arrives with a different one".

### F4 (medium) docs/CONCEPTS.md:150-152 — "pure launch policy" is not pure
`LaunchEligibility.resolve/5` defaults `now` to `System.system_time/1` (lib/foundry/launch_eligibility.ex:53). `Quota.Fallback` reads the clock, `DateTime.utc_now/0` and `:crypto.strong_rand_bytes/1` (lib/foundry/quota/fallback.ex:107, 122, 133, 189; cooldown.ex:17). "No callers" is verified: grep of lib/ finds neither module referenced outside its own file. Fix: drop "pure"; "an uncalled launch policy".

### F5 (low) README.md:29-31 — diagram invents a command syntax
`lane submit <commit> <checkout>` and `lane review: approved | correction | rejected` are not the CLI shape: it is `lane submit <ID> --principal … --candidate <sha> --checkout <dir>` and `lane review <ID> --verdict …` (cli.ex:30-33, 46-48). Fix: use `lane submit --candidate --checkout` / `lane review --verdict` in the arrows, or label the block "schematic".

### F6 (low) docs/CONCEPTS.md:101-102 — protected operation list read as exhaustive
"Protected operations **are** policy, allocation ledger, reservations, effects, receipts and leases": the closed table also holds control, inbox, generations and attempt close (protected_primitives.ex:7 `@operation_types`). Fix: "include".

### F7 (low) docs/CONCEPTS.md:164-165 — "Every change goes through the lane"
Documentation commits are made by the operator directly (b43dc0f, and this candidate's two commits). Fix: "Every code change".

### F8 (low) docs/README.md:88 — layer 4 row contradicts the layer definition
Layer 4 is "designs for code that does not exist yet"; the bounded-effect-query row says "(now implemented)". Move it to layer 5 (dated record, cited by OBSERVABILITY.md) or reword.

### F9 (low) docs/README.md:114 and AGENTS.md:47 — check_docs description is stale
Both still say the checker fails only on unresolved links; it now also fails on missing `#anchor`s. One clause each.

### F10 (low) docs/strategy/PRODUCT.md:6 — bare Pramāṇa SHA recorded after the split
"Moved from Pramāṇa on 2026-09-24 (commit `2ad8ed9`)" is a Pramāṇa commit recorded after 2026-09-23, so README.md:154's rule ("Commit SHAs recorded before the split name Pramāṇa commits") does not cover it. Fix: "(Pramāṇa commit `2ad8ed9`)".

### F11 (low) docs/DURABLE-STORE.md:6-7 — "every lane command goes through the workflow kernel and this gateway"
`lane log` opens SQLite read-only and bypasses the gateway (log.ex:31-33); `lane settle --outcome unknown` and `submit`'s receipt go to the gateway as root commands without the kernel (backend.ex `settle_root/6`). Fix: "every lane write goes through Core's gateway, and every transition through the workflow kernel".

## Checked and found fine

- **Refusal atoms, phases, verdicts, settle outcomes, commands**: `wrong_source_phase` (shared.ex:37), `candidate_mismatch` (backend.ex:280), `principal_not_independent` enforced in Core (protected_primitives.ex:1269-1350, 3332-3460, not only recorded), `allocation_unavailable` (developer.ex:97, review.ex:197), `git_evidence` (cli.ex:500), `gateway_recovery` (cli.ex:238, 278, 453), `ready_to_integrate` on approved after reviewer close (review.ex:332-337), `correction` → `needs_correction` → requeue (review.ex:59-61, dispositions.ex:49-58), `rejected` → ticket phase `rejected` (dispositions.ex:57-58), `non_started`/`unknown` (cli.ex:63), verdict set (cli.ex:62), command set and options (cli.ex:30-45), `lane recover --evidence` (cli.ex:44, server.ex:57).
- **Transport (§1)**: base64 URL envelope, `Foundry.CLI.RPC.run/1`, refusals for encoding/size/UTF-8/JSON/duplicate key/NUL/non-lane shape all present (rpc.ex:17-27, 39-49, 120-128; bin/foundry:52-71).
- **Lane daemon**: `ManualLane.Server` is the only child under `FOUNDRY_MANUAL_LANE=1` (application.ex:30-37, 47-50; bin/foundry-lane:19). Seed refuses a policy whose `independent_of_roles.reviewer` omits developer (server.ex moduledoc); example policy grants 50/50 starts.
- **Submit evidence**: clean worktree, `HEAD == candidate`, base ancestor (git_evidence.ex:53-60). Review notes archived by digest before any write (cli.ex:185-186). `integrated` is read-only `git cherry` (cli.ex:246-268).
- **Core**: WAL + `synchronous=FULL` (database.ex:646-647), `BEGIN IMMEDIATE`/`COMMIT` around every bundle (database.ex:524-541, gateway.ex:592, 1006), capability-gated `protected_command/4` and `atomic_bundle/4` (gateway.ex:61-67, 210-212, 244-246), capability never leaves the Server tree (server.ex moduledoc).
- **Principals**: runbook §4 convention matches the CONCEPTS example and `human:<name>`; only the issuer may submit/review/settle (backend.ex `current_effect/4`, `receipt_provenance_mismatch`).
- **Layout and paths**: lib/foundry tree matches README's layout; `repair/` holds two FR-08A modules; `test/foundry/architecture_boundary_test.exs` exists; `mise.toml` pins the toolchain; `python3` is needed by `test/foundry/effects/process_group_test.exs`.
- **Gate description**: warnings-as-errors compile, format check, provenance manifest (ci.ex:35-40, 156-183).
- **Repair-plan references**: FR-02 complete, FR-09/FR-10/FR-11..FR-17/FR-22/FR-15aB/FR-18A named and statused as README and CONCEPTS say (REPAIR-PLAN.md:515-544). "Pinned Pi RPC" wording matches PI-HARNESS.md:30-31 and STRATEGY.md:217-218.
- **Q13 rewrite**: REPAIR-PLAN.md:36-39, STRATEGY.md:229-232 and PRODUCT.md:330-332 agree: scope no longer limited to one operator/machine/repository, and every new project, operator or host waits on FR-15aB (plan, strategy) plus its own approved scope and policies (product). No dependency edge, ticket status, launch policy, billing rule or review-identity obligation changed; the F01/F04/F06 finding rows and FR-15aB row are untouched. "Pramāṇa must build and run without Foundry" became "Every supervised project must build and run without Foundry" (PRODUCT.md:339-340), a generalization, not a weakening. Completion rule drops only the Pramāṇa PLAN.md entry (REPAIR-PLAN.md:64-66). STRATEGY's rewritten execution baseline (lines 285-292) matches the code: nothing launches; the anchor renamed there resolves from PRODUCT.md:371.
- **bin/check_docs.exs**: green on the checkout (`0 broken link(s)`, exit 0). Red control in a scratch copy under the scratchpad: 6 seeded defects all reported (anchor inside a fenced block, missing anchor, non-existent `-2` duplicate, missing anchor in another file, percent-encoded path with a bad anchor, empty fragment), and every deliberate pass passed (`-1` duplicate, inline code/emphasis/link stripped, em dash producing `--`, `id="…"` anchor, non-ASCII heading, percent-decoded path, non-.md target with fragment). Same-file `#anchor` links are now checked (they were skipped before). Residual limits, none hit in the tree: only ``` fences are recognized (not `~~~` or indented), headings indented 1-3 spaces are not matched, fragments are not URI-decoded (no `%` fragments exist in tracked docs).
- **ci.ex env vars**: `git grep` outside docs/ finds no `COORDINATOR_TICK`, `HERDR_ENV`, `coordinator_tick` or `herdr_env` in lib/, test/, ci/, bin/, config/, .github/ or rel/. No consumer of the removed provenance keys. `mix test test/foundry/ci_test.exs`: 11 passed.
- **Navigation**: every tracked .md outside the three exclusions has the breadcrumb at line 3 and its tail equals the H1 (differences are only stripped backticks and "Docs" for the index). Every non-review doc is reachable from README.md via docs/README.md; the 14 fr-08 files not in the index are all listed by docs/fr-08/README.md, which is.
- **Pramāṇa links**: outside docs/batch-d/reviews/ the only `lorecrafting/pramana` matches are the quoted grep commands in CLEAN-ROOM-SWEEP-2026-09-23.md:36, 147, 304, as expected.
