# ML-XREF-PP-RATCHET independent review

Verdict: **approved**
Reviewer: `agent:codex-gpt-6-astra/review-ML-XREF-PP-RATCHET`
Candidate: `b6b8afd36bd37b32e9e7f36ff3ea40b67241c8fc`
Base: `a9c59dcadcd4cd780de92cff14eff00097ed460b`

## Correctness and scope

No findings. The complete candidate diff changes only `bin/check_xref.exs` and
`test/foundry/xref_check_test.exs`: six insertions and six deletions. The checker raises
only the direct compile-edge limit, from 12 to 18; the existing threshold test moves
from 13/12 to 19/18. Cycle ceiling 2, forbidden-edge map, counting and exit behavior
are unchanged. No Protected implementation or FR-08A identity changes.

I independently counted direct compile-labelled pairs in both supplied JSON graphs:
base 12, Protected candidate 18, six additions and no removals. I independently ran
`MIX_ENV=test mix xref graph --format json --output - --no-compile` in both PP base
and PP developer checkouts; each compiler graph exactly matched its supplied JSON.
These commands used existing compiler manifests and did not edit either checkout.

The six additions are the exact edges prescribed by the design's shared-attribute table:

- Operations -> Guards (`dimensions`)
- Operations -> Rows (`closed_effect_statuses`)
- ReadSet -> Rows (`operation_types`)
- RestartCheck -> Guards (`dimensions`)
- TransitionReplay -> Rows (`closed_effect_statuses`)
- ProtectedPrimitives -> Rows (`operation_types`)

An independent transcription of the approved design's full allowed-edge table found
zero violations among Protected sources, including the facade. A separate graph walk
confirmed the Protected sibling graph is acyclic. Independent reachability-based SCC
counting found two cyclic components in each full graph: the existing workflow SCC
and the Core SCC, whose membership expands with the extracted Protected modules.
The existing whole-graph cycle count measures SCCs, not individual simple cycles;
this change neither alters nor claims to strengthen that pre-existing limitation.
No baseline mismeasurement or cheaper safe correction was found.

## Checks and independent red controls

- `TMPDIR=/private/tmp MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix test test/foundry/xref_check_test.exs`: 4 passed, both before and after mutation/restoration.
- Candidate checker against real PP graph: exit 0, `2/2 cycles, 18/18 compile edges, 0 forbidden split edges`.
- Real PP graph plus one independent compile edge: exit 1, `19/18 compile edges`.
- Real PP graph plus Rows -> Gateway runtime dependency: exit 1, `1 forbidden split edges`, exact offending pair printed, compile count remains 18.
- Real PP graph plus a new two-node runtime cycle: exit 1, `3/2 cycles`, compile count remains 18.
- Exact-string mutation in reviewer worktree only, `@compile_limit 18` -> `@compile_limit 19`: focused threshold test exits 2; `Assertion with != failed, both sides are exactly equal`, `assert status != 0`, `left: 0`. Result: one failing test, three excluded. Original bytes restored in a `finally` block, then all four tests passed.
- Detached reviewer worktree remains clean at the exact candidate SHA.

## Ponytail Review

Lean already. Ship. The existing checker and existing regression test suffice; no new
helper, dependency, abstraction or duplicate test was added.

## Limits

This approves only the narrow ratchet candidate. The Protected implementation has its
own review and integration obligations. No full gate, FR-08A rebind, integration,
provider session or deployment was run or claimed.
