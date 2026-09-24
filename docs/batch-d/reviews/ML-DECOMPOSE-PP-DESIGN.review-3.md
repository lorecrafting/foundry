approved

Ticket ML-DECOMPOSE-PP-DESIGN, review 3 (second correction round). Candidate
8b389c190c2e5b0ff413c7cc71e83b5ae26a63f3 on base e74fb88 (previous candidate f5dbf47).
Reviewer agent:claude-fable-5-1/review-ML-DECOMPOSE-PP-DESIGN-3, detached worktree
/private/tmp/review-ML-DECOMPOSE-PP-DESIGN-3.
Scope: `git diff --stat f5dbf47 8b389c1` is one file, docs/design/DECOMPOSE-PROTECTED-PRIMITIVES.md
(+43 −16); `git diff --name-only e74fb88 8b389c1` is that one file, inside the packet scope.
Worktree clean (`git diff --exit-code`).

Both of review 2's fixes landed and reproduce against the code. No finding blocks an
implementer. Notes below need no change.

## Findings

### Review 2 must-fix (rule 13 vs the C9 pin commit): fixed, verified mechanically

design:137–141 declares `@protected_sites [{Foundry.Repair.FR08AProtectedBoundary, {:@, :api_identity}}]`
"the way rule 4 declares `@software_sites`" and says the list may shrink, never grow.

- Expressible exactly as rule 4: `walk/5` at architecture_boundary_test.exs:240–244 sites
  every node inside a module-attribute value as `{mod, {:@, name}}`, and rule 4 rejects by
  `site in @software_sites` (:99). The same reject over `@protected_sites` is the whole
  mechanism; nothing new is needed in the scanner.
- Narrow and cannot mask a real call: I copied the test's walk/references verbatim into a
  scratch script (scratchpad/rule13.exs, outside the repo) and ran it over three copies of
  the real provider: (a) with seven `Protected.*` tuples added to `@api_identity`: 7 raw
  references, all at the one site `{FR08AProtectedBoundary, {:@, :api_identity}}`, 0 after
  the exception; (b) (a) plus `alias Foundry.DurableStore.Protected.Rows, as: R` and
  `def leak(x), do: R.update_ledger(x, x, x)`: 9 raw, 2 survive the exception, at sites
  `{…, :alias}` (line 61) and `{…, {:def, :leak}}` (line 62), so a call is found; (c) (a)
  plus a def that reads `@api_identity`: 0 survive, because `Ast.bindings/1`
  (test/support/ast_modules.ex:41–42, `resolve/2` :53–59) binds nothing for a list-valued
  attribute, which is also why the kernel's `@families` reads at kernel.ex:102 and :168
  keep rule 4 green today. `lib/**/*.ex` today: 0 `Protected.*` references.
- Residual, same class as rule 4 accepts: a compile-time call written inside the
  `@api_identity` value itself would sit at the excepted site. Not a defect of this design.

### Review 2 should-fix (rebind step 3): fixed

design:165–169 replaces the impossible "all 14 placeholders appear" with
`grep -c 'pin-' <provider> <test>` printing 0 for both. Verified: bin/rebind_fr08a.exs:52
prints `String.slice(o, 0, 8)`, so placeholders are indistinguishable in the output;
`grep -c 'pin-'` on provider and test at 8b389c1: 0 and 0. The dirty-tree refusal is now
cited at 17–18 (design:163), which is where `git status --porcelain` and the `raise` are.
Nit, no change: `grep -c` exits 1 when both counts are 0, so an operator who chains it with
`&&` will see the chain stop; read the two printed counts, not the exit code.

### Allowed-edge table (design:83–101): matches the verified assignment

- Split-set column equals review 2's measured edge list exactly:
  `guards,readset,reads,replay,facade -> rows`, `operations -> guards,rows`,
  `restart -> guards,replay,rows`, `facade -> operations,readset` (+ defdelegate to
  Guards, Reads, RestartCheck). Rows has no sibling edge.
- Outside-the-split column checked for all eight modules, not three: scratchpad/edges3.exs
  walks every `__aliases__` node in protected_primitives.ex and buckets it by §2's line
  runs. Foundry-module references per module: facade Database; Rows Database, Encoding;
  Guards Database; ReadSet Database; Reads Database, Encoding; Operations Database,
  Encoding; TransitionReplay Database; RestartCheck Database, Encoding, TransitionPlan
  (5665), Foundry.DurableStore.Gateway (6048). Every one is inside the table's column and
  no unlisted Foundry module appears; Encoding is absent from four modules, which the
  "upper bound" sentence (design:99–101) covers. Unassigned lines are only 1 (`defmodule`)
  and 4 (the alias line).
- Nit, no change: the table lists Foundry modules only; stdlib (`Enum`, `Map`, `MapSet`,
  `Base`, `String`, …) and Erlang modules are used everywhere. An xref-graph test built
  from "any edge not listed is a defect" must scope to `Foundry.*`; obvious, but one
  parenthesis would remove the ambiguity when ML-PRECISION-TOOLING writes it.

### Planned-tooling paragraph (design:190–200): informational

ML-PRECISION-TOOLING is not referenced anywhere else in docs/ (grep: 0 hits outside this
file). The paragraph is labelled an operator note, is conditional ("If it lands"), and
states that the module boundaries, edge list and invariants are unchanged either way, so
it adds no obligation an implementer could follow wrongly.

### No regressions

C1 row (design:242) now names `@protected_sites`; §3 rule 13 text, C1 and C9 agree. No other
line of the design changed (diff read in full). `elixir bin/check_docs.exs`: 0 broken links.

## Commands and counts

- `git diff --stat f5dbf47 8b389c1`: 1 file, +43 −16. `git diff --name-only e74fb88 8b389c1`: 1 file.
  `git diff --exit-code`: clean.
- `elixir scratchpad/rule13.exs` (copies architecture_boundary_test.exs:181–278 + test/support/ast_modules.ex):
  (a) raw 7 / after exception 0; (b) raw 9 / after 2 (alias + def); (c) raw 7 / after 0; lib today 0.
- `elixir scratchpad/edges3.exs`: external Foundry edges per split module as listed above; 0 unlisted.
- `grep -c 'pin-'` provider, test: 0, 0. `sed -n 17,18p bin/rebind_fr08a.exs`: status + raise. Line 52: 8-char slice.
- `grep -rn ML-PRECISION-TOOLING docs` excluding this design: 0.
- `elixir bin/check_docs.exs`: 0 broken links.
- Read in full: the delta, test/foundry/architecture_boundary_test.exs (293), test/support/ast_modules.ex (60),
  bin/rebind_fr08a.exs (57), lib/foundry/repair/fr08a_protected_boundary.ex:1–70 plus every
  `@api_identity` / `Foundry.DurableStore.` line (13, 18–49, 60, 629), design §1–§2.
- No tests run (design-only change; focused tests only, none applicable).
