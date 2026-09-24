approved

Re-review of ML-DECOMPOSE-GATEWAY-DESIGN, candidate 1f50910e390ec344c2d591cfe3bb151b8ea19dcd (base e74fb88, first candidate 9e4a710), reviewer agent:claude-fable-5-1/review-ML-DECOMPOSE-GATEWAY-DESIGN-2, worktree /private/tmp/review-ML-DECOMPOSE-GATEWAY-DESIGN-2. Scope: the delta `git diff 9e4a710 1f50910` touches exactly docs/design/DECOMPOSE-GATEWAY.md (+69 -29), inside the packet scope; total against base is still that one file (+256). `elixir bin/check_docs.exs`: 0 broken link(s). Scope of this review is the delta and regressions it could introduce; the first review's verified findings are not re-derived.

Both required corrections are in and correct, all four minor fixes are in, and the delta introduces no regression. Verdict: approved. The nits below are non-blocking and none would send an implementer or the rebinding lead to a wrong result.

## Correction 1 (FR-08A rebind procedure): walked against bin/rebind_fr08a.exs, holds

Step 1. Six distinct placeholders, one per slot. The script builds `[{old_sha, new_sha}, {old_md5, new_md5}]` per entry (:28-41) and applies each with `String.replace/3` over provider and test (:45-49), so distinct placeholders make each pair hit exactly one slot. The placeholder strings are not substrings of anything in the provider, the test or the report (`grep -c "pin-"`: 0, 0, 0), contain `-` so cannot collide with any hex old value, and no placeholder is a substring of another. They compile (strings in `@api_identity`), and `identity/0` -> `implementation_binding/0` -> `loaded_api?/1` (fr08a_protected_boundary.ex:628-645) compares them as strings without decoding, so the script's call to `identity()` at :30 yields `mismatch` without raising. The regex at :31-34 (`\{(Foundry\.[A-Za-z0-9.]+),\s*"<path>"`) matches a tuple whether `mix format` keeps the path on the module's line or wraps it (as for ProtectedPrimitives at :28-29); `[[module_name]] =` needs the path exactly once, which a hand-added tuple satisfies. `module.module_info(:md5)` at :38 autoloads the new modules from the test build like the existing pins. `== 10` -> `== 13` at test line 12 is right; lines 45-49 pin per-file lines only for protected_primitives.ex and gateway.ex, so no new test lines are needed; ML-DEAD-ROUTES' `== 12` case is stated.

Step 2. Commit first: the script raises on a dirty tree and reads HEAD/HEAD^{tree} for the subject (:15-18). Correct.

Step 3. Run the script. Ordering: pairs are `[subject, tree | per-entry sha, md5 ...]` (:43). No new value can equal a later old value (hex hashes vs placeholders with `-`; the hex-on-hex collision risk is the same as every earlier rebind). The gateway.ex old sha/md5 occur in both provider (:22-23) and test (:48) and are rewritten in both. Nothing is written twice.

Step 4. Fresh-VM regeneration with the printed command (:53-57); the test asserts byte-equality with the report at test line 41. Correct.

Step 5. Test green and `ready=true`; three files in the rebind commit. Matches the script header (:5-6).

Outcome: FR-08A green with every new pin's sha256 and beam_md5 correctly filled. No placeholder collision or ordering hazard remains.

## Correction 2 (move check via debug_info): concrete, and it catches the Kernel shadow

Tried it, throwaway script outside the repo (scratchpad/defs_check.exs) against the test build of this worktree:

- Base `Gateway` beam: 131 definitions, `%{def: 25, defp: 106}`, exactly as §4 step 2 claims. `normalize_candidate/1`'s call target is `Foundry.DurableStore.Kernel` (alias expanded). `open/2` contains the literal `5000` once (attribute inlined).
- Alias shadow: two modules whose `def f(p), do: Kernel.normalize_bundle(p)` clause is source-AST-equal after meta stripping (`true`) have different `debug_info` definitions (`false`): `[Foundry.DurableStore.Kernel, :normalize_bundle]` vs `[Kernel, :normalize_bundle]`. The method sees what `Code.string_to_quoted!` cannot.
- Synthetic move (attribute, alias, guard, pipe and capture in the moved body), normalised per step 3 (strip meta, defp->def, rewrite `{{:., _, [M, f]}, _, args}` for the named modules to `{f, [], args}`): good candidate == base `true`; alias-forgetting candidate == base `false`.

The `:beam_lib.chunks` / `backend.debug_info(:elixir_v1, mod, data, [])` / `definitions` path is exactly as written and debug_info is present in the default test build (mix.exs sets no `elixirc_options`). Gateway.ex has no `import`/`require`/macro beyond `use GenServer` (region A, stays), and no `defmacro` exists under lib/foundry/durable_store or lib/foundry/repair, so no macro expansion can smuggle the enclosing module atom into a moved body.

## Minor fixes 3-6 and the added line: all in and verified

- T1: D holds two copies (gateway.ex:2103, :2170); `current_seq/1` at :1946 is B; `last_sequence/1` is maintenance.ex:42-47. Stated correctly now.
- Region B "Calls into" lists TransitionPlan (`slot_event_types/0`, :1477). Verified.
- `:status` (127-129) named as the one `handle_call` without a recovery clause. Verified.
- T2: docs/DURABLE-STORE.md contains no `gateway.ex` path (grep: none); docs/REPAIR-PLAN.md:240 has "`gateway.ex` (2,377)" and is left as a dated figure. WORKFLOW-CONTRACT rows 178/184 and domain_read_check_test.exs:75 still cite `gateway.ex`. Verified.
- §6: the one-line note that no protected_primitives design note exists at this base is in.

## Nits (non-blocking, fix whenever the note is next touched)

1. §3 line cites into bin/rebind_fr08a.exs are off by one: the dirty-tree refusal is :17-18 (not 16-17); the printed regeneration command is :53-57 (not 52-56).
2. §3 step 3 "check that all six placeholders appear": the script prints `String.slice(o, 0, 8)` (:52), so the six lines read `pin-sha2 -> ...` x3 and `pin-md5- -> ...` x3: countable as six, not attributable per module. Placeholders whose first eight characters differ (e.g. `domaincommit-sha256-pin`) would make the printout self-explaining. Cosmetic.
3. §3: the subject revision will be the placeholder commit (provider + test edits only), not "the protected change itself" as the script header (:5) puts it. Nothing reads the subject's content (fr08a_protected_boundary.ex:109-112 only compares it), so this is fine; one clause saying so would stop the lead from wondering.
4. §4 step 3 "strip all meta": each clause in `definitions` is a 4-tuple `{meta, args, guards, body}`, which `Macro.prewalk` does not enter; the implementer must walk `args`, `guards` and `body` per clause (my first attempt walked the clause list and stripped nothing). One clause in the note saves the implementer the same ten minutes.
5. §4 step 3's rewrite covers call nodes only. A remote capture `&M.f/n` expands to `{{:., _, [M, f]}, _, []}` inside `:/`, whose local form is `{f, meta, nil}`, so a capture that crosses a seam would produce a false diff (a false positive, so the check stays sound). gateway.ex has exactly one local capture (`&normalize_json/1`, :1257, region C to C), so none crosses a seam here; the rule matters when the script is reused on protected_primitives.ex, as §4 intends.
6. §4 step 1 hardcodes `e74fb88` as the base, but §5 lands ML-DEAD-ROUTES first, and per-commit checking of M2/M3 needs the previous commit as base. Say "the parent of the commit under check".

## Commands run (all in the review worktree, HEAD 1f50910, tree clean before and after)

- `git rev-parse HEAD`, `git status --short` (clean), `git diff --stat 9e4a710 1f50910` (1 file, +69 -29), `git diff --stat e74fb88 1f50910` (1 file, +256), `git diff 9e4a710 1f50910` (read in full).
- `elixir bin/check_docs.exs`: 0 broken link(s).
- Read: bin/rebind_fr08a.exs (all 57 lines), fr08a_protected_boundary.ex:1-80, :100-120, :620-648, fr08a_protected_boundary_test.exs:1-62, gateway.ex:127-129, :1475-1478; maintenance.ex:42-47; REPAIR-PLAN.md:240.
- grep: `coalesce(max(seq)` (gateway.ex 3: 1946, 2103, 2170; maintenance.ex 1: 43); `gateway.ex` in DURABLE-STORE.md (0), WORKFLOW-CONTRACT.md (178, 184), domain_read_check_test.exs (75); `subject_tree` uses (provider :58, :93; test :11); `debug_info|elixirc_options` in mix.exs (0); `defmacro` under lib/foundry/durable_store and lib/foundry/repair (0); `import|require|use` in gateway.ex (1: `use GenServer` :9); `pin-` in provider/test/report (0/0/0); local captures `&f/n` in gateway.ex (1: :1257).
- `MIX_ENV=test mix compile` in the worktree (55 beams), then `MIX_ENV=test mix run --no-start <scratchpad>/defs_check.exs`: Gateway 131 definitions (25 def, 106 defp); Kernel target `Foundry.DurableStore.Kernel`; `5000` in open/2: 1; alias-shadow source-AST equal true / definitions equal false; synthetic move good==base true, bad==base false.
- No repo tests run: the candidate changes documentation only. FR-08A untouched.
