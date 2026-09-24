approved

Reviewer: agent:claude-fable-5-1/review-ML-GATE-EVIDENCE-TOOLS
Candidate: e11f6699d0016046cf8b4f7f1046f6a38eb8e679 (base e74fb8803cb2e1127053472fc430d1d300b10a3a)
Worktree: /private/tmp/review-ML-GATE-EVIDENCE-TOOLS (detached; `git diff --exit-code` clean at the end)

## Verdict

Approved. The two tests enforce real properties: five exact-string breaks each turn the
focused run red at the intended assertion, and the one that stays green (an uncommitted
contract edit) is the leniency the operator accepted, documented in both the test comment
and docs/EVIDENCE-TOOLS.md:103-109, and unreachable in the gate because lib/foundry/ci.ex:113-116
refuses a dirty tree before `mix test` runs. All four changed paths are inside the packet scope.

## Findings, ranked

1. (low, note only) test/foundry/evidence_tools/evidence_scripts_test.exs:45 pins the table as
   chunk 2 of `String.split(out, "\n\n")` with `stderr_to_stdout: true`. A future compiler
   warning from the child `elixir` (Elixir warnings end in a blank line) would shift the chunk
   and fail the gate with the raw output in the message. That fails loud, not silent, and CI pins
   the same Elixir 1.20.3 / OTP 29 that ran clean here, so no change is needed.
2. (low, pre-existing, not this ticket) docs/EVIDENCE-TOOLS.md:189-190 still says "across
   `kernel.ex` and `kernel/event.ex`"; since 2026-09-23 the script reads every family module
   under kernel/ and its output names them. Wording only.
3. (low, pre-existing) bin/refusal_sites.exs:87 scans raw lines, so a `{:error, :x}` inside a
   comment counts as a site. The pinned table makes such a drift visible rather than silent.
4. (info) The pinned table is a gate-enforced source, not a derived count restated in prose;
   the doc adds no numbers and keeps its warning about the stale 74/47/27.

## Attack results

1. Real enforcement: red controls A, B, D, E, F below each fail exactly one test; C passes
   as designed. Green run: `Result: 2 passed`, 0.6 s.
2. Portability: gate runs `mix test` with `cd: root` in the repo (lib/foundry/ci.ex:308), only
   MIX_BUILD_PATH/MIX_DEPS_PATH/TMPDIR are relocated, so `.git` and `bin/` are present and
   `System.find_executable("elixir")` resolves from the same PATH that found `mix`. The test
   hardcodes no /private/tmp and spawns no shell. Depth-1 history: fetched the candidate SHA
   with `git fetch --depth 1` into a fresh repo (1 reachable commit) and both scripts ran, the
   diff script printing `CONTENT PRESERVED`, exit 0.
3. Determinism: `Path.wildcard` is sorted, groups sort by `{-count, name}`, atoms sorted,
   fixed-width padding, no locale-dependent calls. Same output on three runs.
4. Speed: each script ~0.3 s wall; both tests 0.6 s.
5. Number duplication: none added to prose (finding 4).
6. Scope: changed paths = bin/contract_annotation_diff.exs, bin/refusal_sites.exs,
   docs/EVIDENCE-TOOLS.md, test/foundry/evidence_tools/evidence_scripts_test.exs; all in scope.
   FR-08A pins none of them (grep of test/foundry/repair/fr08a_protected_boundary_test.exs: 0 hits).

## Commands run (worktree, MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps, TMPDIR=/private/tmp)

- `mix test test/foundry/evidence_tools/evidence_scripts_test.exs` — Result: 2 passed, 0.6 s (run 3 times)
- Red controls, each an exact-string edit, focused run, exact reverse (script in scratchpad redctl.sh):
  - A `{:error, :invalid_state}` -> `{:error, :invalid_state_reviewer}` in lib/foundry/workflow/kernel.ex: 1/2 passed, refusal_sites test red (table mismatch)
  - B `ok_or\(` -> `ok_orx\(` in the scanner's spellings: 1/2 passed, `RED CONTROL FAILED: ... unknown_entity_kind`
  - C `Create a fresh attempt` -> `Create a REVIEWERWORD attempt` in docs/WORKFLOW-CONTRACT.md: 2 passed (documented leniency)
  - D `"#{rev}:#{contract}"` -> Pramana-era `Path.join("foundry", contract)`: 1/2 passed, MatchError on `git show`
  - E diff red control tamper `"fresh", "new"` -> `"fresh", "fresh"`: 1/2 passed, `RED CONTROL FAILED: a changed word reported as identical`
  - F append `, reviewer_ghost` to a pinned table row: 1/2 passed
  - `git diff --exit-code --stat` after all six: clean
- `elixir bin/refusal_sites.exs` — red control passed, 30 outside sites in 19 rows; 0.27 s
- `elixir bin/contract_annotation_diff.exs HEAD` — 196 markers, CONTENT PRESERVED; 0.32 s
- Depth-1 fetch of e11f669 into scratchpad/shallow: both scripts exit 0
- `elixir bin/check_docs.exs` — 0 broken link(s)
- `mix format --check-formatted` on the two scripts and the test — clean
- Not run: ci/run.exs, full suite (standing rules)
