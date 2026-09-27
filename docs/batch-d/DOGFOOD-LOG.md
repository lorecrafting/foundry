# Dogfood log: the manual lane

[Foundry](../../README.md) › [Docs](../README.md) › Dogfood log: the manual lane

The operator's running record of Foundry work driven through the manual lane
([runbook](LANE-RUNBOOK.md)). One entry per ticket, then the frictions found in the lane,
its tooling or the runbook. The lane store is the authoritative trail (`bin/foundry lane
log`); this log records what the operator saw and decided.

Roles: operator = an LLM session; developer = a worktree agent; reviewer = a fresh agent
on a different model, never the developer. Principals name the provider, model and ticket.
Integration is manual: cherry-pick onto an integration branch, run one local gate per batch,
then fast-forward `main` after PR CI.

## Handoff: where the campaign stands

Updated at every batch end, so any operator session (Claude, Codex or a human) can resume
cold from the repository alone. Read this, then [the runbook](LANE-RUNBOOK.md), then
[the agent brief](../AGENT-BRIEF.md).

**State (2026-09-26, C2 landed).** `main` and `origin/main` reached clean
`8f3710b3a537d9a3ab6399c972076a558206e751` through [PR #18](https://github.com/lorecrafting/foundry/pull/18).
The five C2 tickets—precision tooling, Gateway, move-check context, xref ratchet and
Protected Primitives—have independent recorded reviews and `lane integrated` receipts;
their exact candidate and integration commits are in the ticket table below. Both Core
splits were rebound once on their integrated tips. The final FR-08A report has 19 pins,
`ready=true` and a 4/4 focused test. The move checker allows only the documented direct
`Enum.map/2` and `Enum.flat_map/2` mapper case; arbitrary closure identity remains outside
its claim. The lane remains on store 3, with stores 1 and 2 archived.

One local C2 gate passed on clean `43c5383` with pinned Elixir 1.20.3, OTP 29.0.5 and
ERTS 17.0.5: 812 model-free tests, warnings-as-errors compilation, formatting,
dependency inventory and escript build. Its provenance is
`/private/tmp/foundry-C2-gate-pinned-2026-09-26/provenance.json`. `main` advanced during
CI only by adding `docs/design/OMA-SUBSTITUTION-EVALUATION.md`; the integration branch
merged that document, `check_docs` found zero broken links, and Linux CI passed again on
the final PR tip `8f3710b`. No second local gate was run.

**New target.** The operator chose [portable governed acceptance](../REPAIR-PLAN.md#delivery-sequence-portable-governance-first)
as the first product milestone. Codex, Claude Code and other clients orchestrate agents;
Foundry authenticates and protects exact admission, candidate/check/review evidence,
and operator-triggered exact-candidate promotion to an authoritative accepted ref through
CLI/MCP. It does not claim model-spend control,
agent-session recovery or autonomous execution in this milestone. The first pilot
compares Foundry-governed and ordinary native-client work while building Foundry, with
operator effort and false refusals included. LokaCore stays separate. The Q20 wording
received an independent [correction review](reviews/FOUNDRY-EVALUATION.review-1.md) and
[approval re-review](reviews/FOUNDRY-EVALUATION.review-2.md): actual workflow acceptance,
not a merely promising shadow candidate, is the pilot's primary numerator. An independent Astra
[strategy review](reviews/PORTABLE-STRATEGY.review-1.md) required correction of the
protected promotion boundary and three wording errors; its
[re-review](reviews/PORTABLE-STRATEGY.review-2.md) approved the corrected plan.
The operator clarified that C2's god-module
decomposition still proceeds first; it is maintenance of the retained Core, not a
bundled-orchestrator expansion.

**C3 citation follow-up.** Pi with the OpenAI Codex subscription completed
ML-QUINT-CITATIONS as an ordinary manual-lane developer, and an independent
OpenAI Astra reviewer approved and recorded the exact candidate. The full
one-commit range is on `integ/C3` (`88642b8`), with `lane integrated` true.
One local gate passed on that clean commit with pinned Elixir 1.20.3, OTP
29.0.5 and ERTS 17.0.5: 812 model-free tests, warnings-as-errors compile,
formatting, dependency inventory and escript build. Provenance:
`/private/tmp/foundry-C3-gate-2026-09-26/provenance.json`. This demonstrates
Pi can participate in the existing manual lane; it is not yet the governed
plugin integration promised by ML-PG-CLIENTS.
The fresh C3 batch re-sweep found no actionable issue in the integrated spec,
review or log. Linux PR #21 passed 809 model-free tests; the local macOS gate
passed 812. `main` and `origin/main` reached `063a4a6` through that PR.

**C4 contract design.** ML-PG-CONTRACT defined the proposed version-1
[portable governance contract](../design/PORTABLE-GOVERNANCE-CONTRACT.md).
An independent Astra [first review](reviews/ML-PG-CONTRACT.review-1.md)
caught two high-risk gaps: unaccepted changes could enter through an admitted
base, and promotion could race policy/spec changes or another promotion. A new
Sol principal corrected both; a fresh Astra [re-review](reviews/ML-PG-CONTRACT.review-2.md)
approved the exact two-commit candidate and recorded its verdict. The full
range is on `integ/C4` (`f3cbf99`), with `lane integrated` true. One local gate
passed on that clean commit with pinned Elixir 1.20.3, OTP 29.0.5 and ERTS
17.0.5: 812 model-free tests and all other stages. Provenance:
`/private/tmp/foundry-C4-gate-2026-09-26/provenance.json`. This is reviewed
design, not a working custody or acceptance service.
The fresh [C4 batch re-sweep](reviews/C4-BATCH-RESWEEP.md) found no actionable
issue; Linux PR #22 and the main push CI passed at `7175711`.

**C5 custody design.** The reviewed [first-host custody design](../design/PORTABLE-CUSTODY.md)
records the current same-UID, mode-0644 store/policy and general-RPC gap without
claiming isolation. Astra [review 1](reviews/ML-PG-CUSTODY-DESIGN.review-1.md)
found three boundary gaps: candidate tools could borrow reviewer UID authority,
privileged `--out`/`--notes` paths could reach root files, and revoked UIDs could
retain or regain roles. [Review 2](reviews/ML-PG-CUSTODY-DESIGN.review-2.md)
closed those but found a stale-revision retry contradiction; [review 3](reviews/ML-PG-CUSTODY-DESIGN.review-3.md)
approved the corrected exact candidate. The full three-commit range is on
`integ/C5` (`2758bfe`), with `lane integrated` true. One local gate passed on
that clean commit with pinned Elixir 1.20.3, OTP 29.0.5 and ERTS 17.0.5:
812 model-free tests and all other stages. Provenance:
`/private/tmp/foundry-C5-gate-2026-09-26/provenance.json`. No service account,
socket, accepted ref or hostile-process control was installed or run.

**C6 custody reconciliation design.** The bounded [operator/packet recovery design](../design/PORTABLE-CUSTODY-RECONCILIATION.md) received a [correction review](reviews/ML-PG-CUSTODY-RECONCILIATION-DESIGN.review-1.md) for deferring the original packet-result cut, then an [approval re-review](reviews/ML-PG-CUSTODY-RECONCILIATION-DESIGN.review-2.md) at `a6907df`. The full two-commit range is on `integ/C6-custody-reconciliation-design` with `lane integrated` true. One local C6 gate passed on clean `77e8d54` with pinned Elixir 1.20.3, OTP 29.0.5 and ERTS 17.0.5: 812 model-free tests and all other stages; provenance `/private/tmp/foundry-C6-design-gate-2026-09-26/provenance.json`. [PR #25](https://github.com/lorecrafting/foundry/pull/25) reached final tip `927bfd990fd9427eae16b85738ae531d4452d32d`; its main-push GitHub CI [run 36301965623](https://github.com/lorecrafting/foundry/actions/runs/36301965623) passed at that exact head. The local C6 gate's 812 tests at `77e8d54` and final PR Linux CI's 809 tests were separately reported prior evidence, not rerun here. This is design only: terminal operator non-start still needs selected, reviewed proof sources and a typed workflow handoff. Custody itself remains queued after five correction reviews, uninstalled and disabled.

**C7 autonomous-review design.** The human replaced Q23's proposed per-ticket human verdict with a generic, isolated attestation and preauthorized ordinary accepted-ref promotion target, while keeping protected root/policy maintenance operator-owned. The first `cfb2de8` design candidate had a recorded [approval under older criteria](reviews/ML-PG-AUTONOMOUS-REVIEW-DESIGN.review-1.md); the subsequent workflow-agnostic Core requirement is a separately recorded [operator follow-up](reviews/ML-PG-AUTONOMOUS-REVIEW-DESIGN.operator-followup.md), not an amended verdict. A fresh ticket reviewed the **full** `927bfd9..92d678a` two-commit design range; independent Astra [review](reviews/ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC.review-1.md) and lane event 377 approved it **design-only**. Both cherry-picks have identical tree to the reviewed candidate on `integ/C7-autonomous-review-design` (`a7c82a7`); `lane integrated` reports both ranges present there. The older patch is thus present as a precursor, but its older verdict does not authorize the amended design. One local C7 gate passed at clean `08e05df` with pinned Elixir 1.20.3 / OTP 29.0.5 / ERTS 17.0.5: **812 model-free tests**, compile, formatting, dependencies and escript (provenance: `/private/tmp/foundry-C7-autonomous-design-gate-2026-09-27/provenance.json`). [PR #26](https://github.com/lorecrafting/foundry/pull/26) Linux CI [run 36305787463](https://github.com/lorecrafting/foundry/actions/runs/36305787463) passed **809 tests** at that exact `08e05df` head. A fresh read-only [C7 batch re-sweep](reviews/C7-BATCH-RESWEEP.md) on clean `b8ee85f` found no high/medium issue; its one low stale index status is corrected in the subsequent documentation-only follow-up. The local gate and initial PR checks above apply to `08e05df`, not the final tip. PR #26 final-tip Linux [run 36306574587](https://github.com/lorecrafting/foundry/actions/runs/36306574587) passed **809** on `d4bbe90`; `main` and `origin/main` reached that SHA by local fast-forward, and main-push [run 36306963521](https://github.com/lorecrafting/foundry/actions/runs/36306963521) passed **809** there. `lane integrated` for the full amended design range returned true on `main`. No service, broker, protected verdict or accepted-ref promotion has been installed.

**C8 milestone sequencing.** Packet-provenance [review 1](reviews/ML-PG-PACKET-PROVENANCE-DESIGN.review-1.md) returned **correction**, not approval: P1 custody→candidate→reviewer positive cycle and P1 missing protected consuming-entry selection. The separate acyclic sequence candidate `8f9c26f` received independent [approved—design only](reviews/ML-PG-MILESTONE-SEQUENCE-DESIGN.review-1.md), event 401. Its full one-commit range is on `main` at `ab7f6cd` with `lane integrated` true. One local gate passed on clean `ab7f6cd` with **812 model-free tests** (provenance: `/private/tmp/foundry-C8-milestone-sequence-gate-2026-09-27/provenance.json`); [PR #27](https://github.com/lorecrafting/foundry/pull/27) final-tip Linux [run 36308020588](https://github.com/lorecrafting/foundry/actions/runs/36308020588) passed **809**, followed by main-push [run 36308408054](https://github.com/lorecrafting/foundry/actions/runs/36308408054), **809** at the same head. A fresh independent [C8 re-sweep](reviews/C8-BATCH-RESWEEP.md) found no P0/P1 and one low stale gate-pending status, corrected in this operator handoff. No protected source or host was installed by C8.

**C9 packet provenance design.** Same Sol developer corrected both P1 design findings; a fresh Astra [full-range review 2](reviews/ML-PG-PACKET-PROVENANCE-DESIGN.review-2.md) recorded **approved—design only** at `a86ebce`, event 409. The two reviewed commits are ancestors of `integ/C9-packet-provenance-ancestry` after an operator merge of settled C7/C8 main: both sides added adjacent `docs/README.md` rows. The first linear cherry-pick resolved that conflict but `lane integrated` could not recognize its changed-context patch; the alternate ancestry merge at `1d7f27b` preserved both rows, produced the identical complete tree and reports the full reviewed range `integrated:true`. A P3 old Q23/Q24 attribution typo is corrected in the operator follow-up. One local C9 gate passed on clean `4520c58`: **812 model-free tests** (provenance: `/private/tmp/foundry-C9-packet-provenance-gate-2026-09-27/provenance.json`). [PR #28](https://github.com/lorecrafting/foundry/pull/28) final-tip Linux [run 36309387675](https://github.com/lorecrafting/foundry/actions/runs/36309387675) passed **809** at exact `4520c58`; `main` and `origin/main` fast-forwarded there with `lane integrated:true`. Main-push [run 36309765370](https://github.com/lorecrafting/foundry/actions/runs/36309765370) passed **809** on that same head. A fresh read-only [C9 re-sweep](reviews/C9-BATCH-RESWEEP.md) at `4520c58` found no P0/P1 and one low stale gate/PR-pending handoff, corrected here; neither CI nor the re-sweep establishes Core implementation or installed custody.

**C10 atomic packet binding design.** The same Sol developer finished the stopped conditional design against approved C9 and Q25. Independent Astra [review](reviews/ML-PG-CUSTODY-PACKET-ARCH-DESIGN.review-1.md), event 417, approved exact candidate `7cda7fe` **design only**. The reviewed commit is an ancestor of `integ/C10-packet-binding-ancestry` after an operator merge of settled main and adjacent README rows; the design body remained byte-identical through that merge, and `lane integrated` returned true. One local C10 gate passed on clean `c89fe57` with **812 model-free tests**, pinned Elixir 1.20.3 / OTP 29.0.5 / ERTS 17.0.5, compile/format/dependency/escript (provenance: `/private/tmp/foundry-C10-packet-binding-gate-2026-09-27/provenance.json`). This documentation-only evidence update follows the gate; final-tip PR CI and main landing remain pending. Approval does not validate or enable the suspended architecture-red prototype.

**Next:** preserve C10 final-tip Linux PR CI/landing as a separately verified operator step (the historical C10 status above is not retroactively changed). Before any paused CUSTODY-FOUNDATION Core mutation, obtain an independent exact-candidate design review of the critical [service-owned operator admission ingress](../design/PORTABLE-CUSTODY-OPERATOR-INGRESS.md): the existing manual lane shares a protected capability via `Server.context/0`, self-declares its actor and exposes general release RPC, so it cannot authenticate operator contract/spec admission. This proposed design is not yet approved, implemented or host-tested. Then admit/resume a fresh bounded FOUNDATION implementation on the accepted base under reviewed C9/C10 **and** ingress contracts; reuse any safe prototype code only as a new scoped candidate with rule-3-clean Core and independent review. CUSTODY-FOUNDATION proves actual isolated operator/developer and producer seal/developer positive, **not** full custody → CANDIDATE (verified import/trusted checks against seal) → REVIEW-BROKER (reviewer packet and legitimate scoped **agent** decision) → CUSTODY-CLOSURE (all remaining original hostile-tool, reviewer-positive, revocation and restart obligations) → ACCEPTANCE (ordinary exact-ref CAS) → CLIENTS → EVALUATION. The old human-verdict custody packet is immutable historical evidence. No foundation/import/design result enables the protected route; unknown holds, root/policy maintenance, human administrator provisioning and actual distinct-UID macOS/Linux positive/refusal/restart/red controls remain gates. A nonempty required-check broker packet needs separately admitted complete schema; v1 does not fake `policy_empty`. Pinned `ast-grep` lints remain separate.

**Operator loop, per batch.**

1. Admit each ticket on the current `main` (`bin/foundry lane admit`), with a scope disjoint from
   the other tickets in the batch; issue each developer packet.
2. Developer agents work in their own worktrees and run `lane submit` themselves (Q8); a fresh
   reviewer on a different model gets its own detached worktree at the candidate and runs
   `lane review` itself. `correction` → issue a new developer packet; the correction's
   reviewer uses a new principal (`…/review-<ticket>-2`).
3. Integrate on `integ/<batch>` in a separate worktree: cherry-pick each ticket's full
   `<base>..<candidate>` range and check `lane integrated <ID> --ref integ/<batch>`.
4. If a pinned Core file changed: rebind FR-08A once on the integration head
   (`MIX_ENV=test mix run --no-start bin/rebind_fr08a.exs`, then the report command it prints,
   then the FR-08A test), and commit that as `test: rebind FR-08A …`.
5. Copy the review notes to `reviews/`, update this log (ticket rows, scorecard, frictions,
   this handoff), `git add` then `elixir bin/check_docs.exs`, commit.
6. Push the branch and open a PR (Linux CI runs only on PRs and `main`); run one local gate
   `TMPDIR=/private/tmp elixir ci/run.exs --output <dir outside the repo>` in the integration
   worktree (no `deps` symlink there, F16). Both green → `git merge --ff-only` on `main`,
   push; the PR shows as merged. Never merge from GitHub.
7. If the batch renamed the release or RPC entry, or makes the store unreadable, follow the
   runbook's landing and rotation steps instead of a plain fast-forward (F15, F7).
8. End the batch with a fresh reviewer's re-sweep of everything changed since the last sweep;
   its ranked list feeds the next batch.

**Dogfood assessment at each batch end.** Use the lane log as the event record, then update
the scorecard and F table from observed behavior. For each new friction, record the command or
workflow step that triggered it, what work it cost (retry, review round, gate run, or blocked
ticket), and a specific candidate fix. Turn repeated or high-cost frictions into ranked tickets;
when a fix lands, rerun its original trigger or a red-control drill and record the result. Judge
the lane by real errors caught versus legitimate work blocked and by defects that escaped review,
not by how many events it recorded. Keep manual overhead visible alongside those outcomes.

Ask the operator (the human) before any operator-level decision: record it in the Q table.

**Operator gotchas (learned the hard way; each cost a gate, a review round or work).**

- **Exit codes, not output.** Join shell steps with `&&` and never pipe a check through
  `tail`/`head` when its status matters: a red gate once read as green. The shell here is zsh.
- **Gate result.** `ci/run.exs` writes `<output>/provenance.json`; the verdict is `result`
  and the gated commit is `source.commit`. The gate takes about 6 minutes; wait on the
  process, not on a guess. It refuses a dirty tree, including a `deps` symlink (F16): set
  `MIX_DEPS_PATH=<main checkout>/deps` instead.
- **Never undo with `git checkout` or `git stash`.** Reverse the exact string; checkout has
  destroyed uncommitted work twice, and the stash stack is shared by every worktree.
- **Never commit on the main checkout's `main` by hand.** Integrate on `integ/<batch>` in a
  separate worktree and fast-forward.
- **Worktrees can start on the wrong base.** After creating a developer worktree, confirm
  `git -C <worktree> log -1` is the admitted base before the agent starts.
- **Integrate the whole range** `<base>..<candidate>` (F10), then `lane integrated`.
- **After a protected change,** the developer's FR-08A red is expected; only a scratch
  rebind tells a real failure from the pin (F12). Grep `test/` for every string a ticket
  deletes from config or workflows.
- **A usage limit or crash kills agents silently** (F19): the lane shows `active` or
  `reviewing` forever. Check `lane status` and each worktree's `git status`, and resume the
  same agent if you can; a replacement agent under the same principal breaks one-principal-
  per-instance (F9), so give a replacement a new principal via a new ticket if needed.
- **`blocked` is terminal.** A developer who needs a path outside the admitted scope submits
  `--blocked`; re-admit as `<ticket>-2` with the wider scope and carry the commits (F8).
- **Parallel sessions sweep uncommitted files.** Another session's `commit -a` takes your
  working-tree edits; commit early, and re-read shared docs before editing them.
- **Claims go stale, code rarely does.** Don't copy a count into prose or pin it to a commit
  it wasn't measured at; a measurement ships with the command that produced it.

**Running this without Claude Code's subagents.** The lane doesn't care which tool drives it.
A developer is any agent session in its own worktree
(`git worktree add -b dev/<ticket> <path> <base>`) given the packet file, `AGENTS.md` and
`docs/AGENT-BRIEF.md`; it runs `bin/foundry lane submit` itself (Q8). A reviewer is a fresh
session on a different model in `git worktree add --detach <path> <candidate>`; it runs
`bin/foundry lane review` itself. Name principals by vendor and model:
`agent:codex-<model>/dev-<ticket>`, `agent:claude-fable-5-1/review-<ticket>`; a correction's
reviewer takes a new principal (`…/review-<ticket>-2`). Cross-vendor review (one vendor
develops, another reviews) is the strongest independence the lane can record (A3).

## Setup, 2026-09-23

- Lane built and started with `bin/foundry-lane build` / `start` from `main` at `55037db`,
  fresh store under `~/.local/state/foundry-lane`, example policy (10 developer and 10
  reviewer starts for the store). `lane status`: `mode: ready`.
- Before the lane could run, the split cleanup landed directly (not through the lane):
  `FOUNDRY_MANUAL_LANE_REPO` defaulted to the checkout's parent, which no longer holds the
  repository.

## Tickets

| Ticket | Base | Candidate | Review | Integrated | Notes |
|---|---|---|---|---|---|
| ML-CONTRACT-DIVERGENCES | `55037db` | `05e2f3c` | [approved](reviews/ML-CONTRACT-DIVERGENCES.review.md) | `93fb057` | record the four ledger/control divergences in the workflow contract. Developer verified all four against the code; found the B3 readings proposal's "no layer refuses issue under pause" is stale (the kernel now refuses, `control.ex:40-44`), left as a dated record |
| ML-RUNTIME-PATHS | `55037db` | `7a9b435` | [approved](reviews/ML-RUNTIME-PATHS.review.md), one low finding (Q2) | `1ae3c3b`, `8e61cd9` | agent prompts and generated scopes lose `foundry/` and `workflow/`. Developer also dropped `cd workflow &&` from generated checks and narrowed HardeningPM's leak check to `lib/foundry/`; found `preparation.ex:6` (`cwd: "workflow"`) and `local_exclude.ex:12` (`workflow/local/`) out of scope → next ticket |
| ML-WORKFLOW-DIR | `55037db` | `3fece1a` | [approved](reviews/ML-WORKFLOW-DIR.review.md), one low finding (Q3) | `25f7174` (batch 1) | Preparation's deps.get runs at the root; LocalExclude defaults to `local/`. No `lib/` caller reaches `Preparation.commands` or the Pramāṇa-shaped database checks |
| ML-DEL-DAEMON | `db4334c` | `65e1fa3`, then `742a60d` | [correction](reviews/ML-DEL-DAEMON.review-1.md) (the `ProcessGroup` `:stale_identity` guard lost its only test; five more edge cases for the knowledge note), then [approved](reviews/ML-DEL-DAEMON.review-2.md) | batch A1 | lib 45.5k → 31.8k lines before ML-DEL-LEAVES; lane-only CLI and Application; FR-15aA archived; [moved knowledge](../design/MOVED-KNOWLEDGE-2026-09-23.md). The rereview found a pre-existing flaky `process_group_test` case → follow-up ML-PROCESS-GROUP-FLAKE |
| ML-DEL-LEAVES | `db4334c` | `61b2c3e` | [approved](reviews/ML-DEL-LEAVES.review.md) (one disclosed out-of-scope deletion accepted, F8) | batch A1 | retire the Assessor, Relocation and the FR-19A sync-EIO workflow (C3) |
| ML-DEL-LEGACY-IMPORT | `5fb7603` | `e23075e` | [approved](reviews/ML-DEL-LEGACY-IMPORT.review.md) | batch A2 + FR-08A rebind | H0, LegacyImport/LegacyLine, AtomicFile, Schema deleted; legacy authority tables now fence startup; CI no longer fetches full history. The rebind found the identity-negative fixture still expecting 7 capabilities (F12) |
| ML-DOCS-ARCHIVE | `5fb7603` | `6761d1b` | [approved](reviews/ML-DOCS-ARCHIVE.review.md) | batch A2 | 37 top-level docs → 14; 137 files under `docs/archive/` and `docs/design/`; new router, archive index and OBSERVABILITY |
| ML-LANE-FRICTIONS | `5fb7603` | `fd208d1` | [approved](reviews/ML-LANE-FRICTIONS.review.md) | batch A2 | F1 quiet stdout, F5 notes archive, F6/F10 `lane integrated`, F4 reviewer worktrees in the runbook |
| ML-PROCESS-GROUP-TESTS | `5fb7603` | `c32df8a` | [correction](reviews/ML-PROCESS-GROUP-TESTS.review-1.md): one stale header comment | carried over | correction packet refused `allocation_unavailable` (F7); re-admit as ML-PROCESS-GROUP-TESTS-2 in a fresh store |
| ML-PROCESS-GROUP-TESTS-2 | `69855d9` | `1f5f487` | [approved](reviews/ML-PROCESS-GROUP-TESTS-2.review.md) | batch PG | store 2's first ticket: `c32df8a` cherry-picked unchanged plus the header-comment correction |
| ML-RENAME-NS | `b30d0a2` | `ff0b5d5`, then `f4ca196` | [correction](reviews/ML-RENAME-NS.review-1.md) (the regex made the rename's own descriptions tautological), then [approved](reviews/ML-RENAME-NS.review-2.md) | batch B1 + FR-08A rebind | FR-23b rename 1/3, 314 files. Operator exception: pinned-commit permalinks in `archive/AUDIT-2026-09-12.md` keep their old paths (rewriting them 404s). The developer opened a copy of store 2 with the renamed build: `mode: :ready`, so no rotation here |
| ML-RENAME-BIN-ENV | `9c7fe01` | `c73b6ea` | [approved](reviews/ML-RENAME-BIN-ENV.review.md) | batch B2 | FR-23b rename 2/3: the wrapper is `bin/foundry`, five env vars are `FOUNDRY_*`, no aliases. Retired Pramāṇa-only `bin/pramana-*` script names left for the archive drop (Q10). Reviewer: `FOUNDRY_STARTUP_MODE` has no reader (batch C dead vocabulary) |
| ML-DOCS-ARCHIVE-DROP | `ecdbc84` | `29185be` | [approved](reviews/ML-DOCS-ARCHIVE-DROP.review.md) | batch B3 | Q10: `docs/archive` (138 files) deleted; 67 inbound links are permalinks at tag `records/2026-09-24`, all verified at the tag. `pramana` matches 675 → 197 |
| ML-RENAME-DOMAIN-TAGS | `6a13b7c` | `1805695` | [approved](reviews/ML-RENAME-DOMAIN-TAGS.review.md) | batch B4 + FR-08A rebind | FR-23b rename 3/3: 12 digest/schema tags `pramana-foundry-*` → `foundry-*`, code prefixes renamed, one golden digest recomputed (reviewer reproduced it), seed 50/50 (Q9). Remaining `pramana` matches outside `docs/fr-08` are a checked-in allowlist ([sweep §5.1](../fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md#51-what-still-says-pramana-after-fr-23b-allowlist)). Store 2 archived; store 3 seeded fresh |
| ML-FR08-TRIAGE | `b9d8311` | `7e4621e` | [approved](reviews/ML-FR08-TRIAGE.review.md) | batch C1a | `docs/fr-08`: 58 dated files pinned at `records/2026-09-24` and deleted, 20 kept because code reads or cites them, 1 kept as authority; the `pramana` allowlist now covers the whole repo. First ticket whose developer and reviewer ran their own `submit` and `review` (Q8) |
| ML-LANE-FRICTIONS-2 | `b9d8311` | `6cf04a5` | [approved](reviews/ML-LANE-FRICTIONS-2.review.md) | batch C1a | F17 refusals exit 1 without a stack trace (the reviewer proved on two nodes the daemon survives), F13 one refusal renderer, F18 `check_docs` reads the working tree, `bin/foundry` fallbacks deleted, runbook steps for F7/F14/F15. The developer's first `submit` passed a short SHA and was refused (`git_evidence`) |
| ML-DEAD-VOCAB | `b9d8311` | `7a0ebb3` (blocked) | none | carried into -2 | submitted `--blocked`: two acceptance items needed paths outside its scope (F8 again). `blocked` is terminal, so the work was re-admitted |
| ML-DEAD-VOCAB-2 | `b9d8311` | `ec4b04c` | [approved](reviews/ML-DEAD-VOCAB-2.review.md) | batch C1a + FR-08A rebind | dead FR-08B functions, unused command/intent/event types, legacy import codecs and the test-only v1/v2 migration deleted (about 600 lines of lib); FR-08A's forged command is now `enqueue` and still trips the same guard (red control). Found test-only: the `transact_verified`/`ProtectedVerifier` route and the `Observations` module |
| ML-GATE-EVIDENCE-TOOLS | `e74fb88` | `e11f669` | [approved](reviews/ML-GATE-EVIDENCE-TOOLS.review.md) | batch C1b | `refusal_sites` and `contract_annotation_diff` run in the gate as ExUnit (pinned table of 30 sweep-unreachable refusal sites); the diff tool had crashed on every run since the split (`foundry/<path>`) |
| ML-DEAD-ROUTES | `e74fb88` | `1414280` | [approved](reviews/ML-DEAD-ROUTES.review.md) | batch C1b + FR-08A rebind | the test-only `transact_verified` route and `ProtectedVerifier` deleted (FR-08A now pins 9); `Observations` kept because FR-18A is in progress (Q11) |
| ML-DECOMPOSE-GATEWAY-DESIGN | `e74fb88` | `9e4a710`, then `1f50910` | [correction](reviews/ML-DECOMPOSE-GATEWAY-DESIGN.review-1.md) (the rebind placeholders would have left FR-08A red; a source-AST move check cannot see alias shadowing), then [approved](reviews/ML-DECOMPOSE-GATEWAY-DESIGN.review-2.md) | batch C1b + operator fixup | [design](../design/DECOMPOSE-GATEWAY.md): Gateway facade + DomainCommit + AtomicBundle + Maintenance. The operator aligned its rebind steps with ML-DEAD-ROUTES and the sibling review |
| ML-DECOMPOSE-PP-DESIGN | `e74fb88` | `281e75c`, `f5dbf47`, then `8b389c1` | [correction](reviews/ML-DECOMPOSE-PP-DESIGN.review-1.md) (write fence as an open question; alias collisions; cut clauses), [correction](reviews/ML-DECOMPOSE-PP-DESIGN.review-2.md) (rule 13 would flag the FR-08A pin list), then [approved](reviews/ML-DECOMPOSE-PP-DESIGN.review-3.md) | batch C1b | [design](../design/DECOMPOSE-PROTECTED-PRIMITIVES.md): facade + seven `Protected.*` modules, rule 13 write fence, explicit allowed-edge table, pins 9 → 19 |
| ML-PRECISION-TOOLING | `c55413f` | `2cf11a0`, `3511fee`, `3d3ec73`, `6330387` | [correction 1](reviews/ML-PRECISION-TOOLING.review-1.md), [correction 2](reviews/ML-PRECISION-TOOLING.review-2.md), [correction 3](reviews/ML-PRECISION-TOOLING.review-3.md), [approved 4](reviews/ML-PRECISION-TOOLING.review-4.md) | integ/C2 (`229ffc4`), landed on main | OpenAI-only developer/reviewer on different models (Q15). Fourth review closed default-generated arities and restricted facade heads with 29 focused tests and red controls. Full seven-commit range cherry-picked; `lane integrated` reported true; C2 gate and PR #18 passed |
| ML-DECOMPOSE-GATEWAY | `3e27ec0` | `0a8db0b` (five commits) | [approved](reviews/ML-DECOMPOSE-GATEWAY.review.md) | integ/C2 (`aec9734`) + FR-08A rebind (`6955f13`), landed on main | M1–M3 compiled move checks and 103 reviewer focused tests passed; T1 helper changes received a separate probe. `lane integrated` reported true. The contract-citation arity typo was corrected on integration branch; the 12-pin FR-08A report says `ready=true`, 4/4 focused tests passed |
| ML-MOVE-CHECK-CONTEXT | `246bdf9` | `70dd91c` (five commits) | [correction 1](reviews/ML-MOVE-CHECK-CONTEXT.review-1.md), [correction 2](reviews/ML-MOVE-CHECK-CONTEXT.review-2.md), [correction 3](reviews/ML-MOVE-CHECK-CONTEXT.review-3.md), [correction 4](reviews/ML-MOVE-CHECK-CONTEXT.review-4.md), [approved 5](reviews/ML-MOVE-CHECK-CONTEXT.review-5.md) | integ/C2 (`886c743`), landed on main | Direct Enum mapper normalization only; 13 focused tests and 38 independent compiled comparisons passed, real PP check passed, bounded invocation claim recorded. Full range integrated; `lane integrated` true |
| ML-XREF-PP-RATCHET | `a9c59dc` | `b6b8afd` | [approved](reviews/ML-XREF-PP-RATCHET.review.md) | integ/C2 (`ade9a14`), landed on main | Exact approved six-edge delta raises compile ceiling 12→18; 2/2 cycle and forbidden-edge guards retained. `lane integrated` reported true |
| ML-DECOMPOSE-PP | `aa19b69` | `364008a` (two commits) | [approved](reviews/ML-DECOMPOSE-PP.review.md) | integ/C2 (`ee3075e`) + FR-08A rebind (`154dac8`), landed on main | Seven-module split, rule 13 fence and live citations passed 403 reviewer focused tests, compiled 337→347 move check, 18/18 xref, and scratch red controls. Full range integrated; `lane integrated` true. Final 19-pin report `ready=true`, focused test 4/4 |
| ML-QUINT-CITATIONS | `8f3710b` | `0cc860d` | [approved](reviews/ML-QUINT-CITATIONS.review.md) | integ/C3 (`88642b8`) | Pi/OpenAI Sol developer, independent Astra review and lane receipts. Six scoped Quint spec/README files; all 46 distinct module/function/arity citations resolved, non-comment Quint content unchanged, 3/3 typechecks and 6/6 witnesses passed. Full range integrated; `lane integrated` true. C3 local gate: 812 tests passed |
| ML-PG-CONTRACT | `063a4a6` | `5eadca5`, then `55d1ddf` (two commits) | [correction 1](reviews/ML-PG-CONTRACT.review-1.md) (accepted-base equality; promotion exclusion), then [approved 2](reviews/ML-PG-CONTRACT.review-2.md) | integ/C4 (`f3cbf99`) | Version-1 portable contract design; no runtime change. Full range integrated; `lane integrated` true. C4 local gate: 812 tests passed |
| ML-PG-CUSTODY-DESIGN | `7175711` | `2da53b8`, `bea24a1`, then `609fa22` (three commits) | [correction 1](reviews/ML-PG-CUSTODY-DESIGN.review-1.md) (reviewer tools; privileged paths; UID reuse), [correction 2](reviews/ML-PG-CUSTODY-DESIGN.review-2.md) (retry ordering), then [approved 3](reviews/ML-PG-CUSTODY-DESIGN.review-3.md) | integ/C5 (`2758bfe`) | First-host design only; no isolation installed. Full range integrated; `lane integrated` true. C5 local gate: 812 tests passed |
| ML-PG-CUSTODY-RECONCILIATION-DESIGN | `7a41ada` | `df14eef`, then `a6907df` (two commits) | [correction 1](reviews/ML-PG-CUSTODY-RECONCILIATION-DESIGN.review-1.md) (packet result after consumed claim deferred), then [approved 2](reviews/ML-PG-CUSTODY-RECONCILIATION-DESIGN.review-2.md) | integ/C6 (`77e8d54`), [PR #25](https://github.com/lorecrafting/foundry/pull/25), main `927bfd9` | Core operator evidence and atomic original packet design only; no Core change or installed custody. Full range `lane integrated` true on integration branch; prior local C6 gate: 812 passed at `77e8d54`; prior final PR Linux CI: 809; main-push CI [36301965623](https://github.com/lorecrafting/foundry/actions/runs/36301965623) passed at `927bfd9` |
| ML-PG-AUTONOMOUS-REVIEW-DESIGN | `927bfd9` | `cfb2de8` | [approved under older criteria](reviews/ML-PG-AUTONOMOUS-REVIEW-DESIGN.review-1.md); later [operator P1 follow-up](reviews/ML-PG-AUTONOMOUS-REVIEW-DESIGN.operator-followup.md) is not a lane verdict | Patch-equivalent precursor in C7 (`708b5cb`), landed on main `d4bbe90` | Original approval remains historical, not authority for the subsequently required generic role-agnostic design. No protected implementation |
| ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC | `927bfd9` | `92d678a` (two commits) | [approved—design only](reviews/ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC.review-1.md), event 377 | integ/C7 (`708b5cb`, `a7c82a7`, operator `08e05df`), [PR #26](https://github.com/lorecrafting/foundry/pull/26), main `d4bbe90` | Full-range role-neutral review; C7 local gate 812 at `08e05df`, final PR Linux 809 and main-push 809 at `d4bbe90`. `lane integrated` true on main; not installed acceptance |
| ML-PG-PACKET-PROVENANCE-DESIGN | `927bfd9` | `4b78bb4`, then `a86ebce` (two commits) | [correction 1](reviews/ML-PG-PACKET-PROVENANCE-DESIGN.review-1.md) (P1 cycle and consumer selection), then [approved—design only 2](reviews/ML-PG-PACKET-PROVENANCE-DESIGN.review-2.md), event 409 | integ/C9 ancestry merge (`1d7f27b`), [PR #28](https://github.com/lorecrafting/foundry/pull/28), main `4520c58` | Full reviewed range ancestral, `lane integrated` true; C9 local gate 812, final PR and main-push Linux 809 at `4520c58`. No working packet/reviewer |
| ML-PG-CUSTODY-PACKET-ARCH-DESIGN | `927bfd9` | `7cda7fe` | [approved—design only](reviews/ML-PG-CUSTODY-PACKET-ARCH-DESIGN.review-1.md), event 417 | integ/C10 ancestry merge (`2ba2d8c`), final-tip PR CI pending | Exact reviewed packet-binding doc preserved; full-range `lane integrated` true, local gate 812 at `c89fe57`. Not Core/host proof |
| ML-PG-MILESTONE-SEQUENCE-DESIGN | `d4bbe90` | `8f9c26f` | [approved—design only](reviews/ML-PG-MILESTONE-SEQUENCE-DESIGN.review-1.md), event 401 | integ/C8 (`a16f1b9`), [PR #27](https://github.com/lorecrafting/foundry/pull/27), main `ab7f6cd` | Acyclic foundation → candidate → broker → full custody closure. C8 local gate 812 and final PR/main-push Linux 809 at `ab7f6cd`; `lane integrated` true, no installed proof |

Batch A2 (four tickets, three integrated) was integrated with one conflict resolved by hand (the audit moved while a link in it changed) and one FR-08A rebind commit by the operator.

**Store rotation, 2026-09-24.** Store 1 is exhausted (F7), so it was stopped cleanly and archived at
`~/.local/state/foundry-lane.store1-archived-2026-09-24`. Its trail holds all nine tickets
above. The lane was rebuilt from `ff0e366` and started on a fresh store; `lane status`
prints only its result (F1 verified live).

Batch A1 (the two deletion tickets) was integrated the same way, plus one operator fixup commit for links in docs neither ticket could edit.

Batch 1 (the three tickets above) was cherry-picked onto `integ/lane-batch-1`, then run
through Linux CI on a PR and one local gate before `main` fast-forwarded.

## Operator questions and decisions

| # | Question | Status |
|---|---|---|
| Q1 | The `pramana-foundry-*` digest domain tags are persisted and checked on read (`record_codec.ex:258`); renaming them makes existing stores unreadable | **Decided 2026-09-23: hard rename, fresh stores.** The lane store is archived, not deleted, when that ticket lands |
| Q2 | HardeningPM's scope-leak check (`hardening_pm.ex:235`, `roles/hardening_pm.md`) now means `lib/foundry/` only, so an IMPRV ticket scoped to `test/` blocks its batch. Lib-only, or anything inside the checkout? | open |
| Q3 | LocalExclude's default `local/` is unanchored; `/local/` would match `.gitignore` but breaks `verify_protection`'s pathspec | open, low |
| Q4 | `Preparation`'s `@database_checks` (`ecto.create`) are Pramāṇa-project checks with no Foundry caller: delete, or keep for project profiles? | open |
| Q5 | Clean-room sweep Q1–Q12 ([sweep](../fr-23/CLEAN-ROOM-SWEEP-2026-09-23.md#7-operator-questions)) | **Decided 2026-09-23:** delete the legacy daemon stack and amend the plan ([C1–C4](../REPAIR-PLAN.md#clean-room-amendment)); archive FR-15aA; retire H0 + legacy import, Relocation, FR-19A sync-EIO, Assessor; operator hygiene done (legacy `local/`, `handoffs/`, `ci-artifacts/` removed; 3 worktrees, 2 merged branches and 12 `archive/2026-09-20/*` tags deleted). Q2–Q4 above become moot with the deletions |
| Q6 | FR-23b renames: do dated records (`docs/archive`, reviews, fr-08 evidence, this log) keep the old names? | **Decided 2026-09-24: rewrite everything**; only references to the Pramāṇa repository keep the name |
| Q7 | Do the Pramāṇa-era env names and wrapper keep working as aliases after the rename? | **Decided 2026-09-24: hard rename, no aliases** |
| Q8 | Should agents run their own lane commands? | **Decided 2026-09-24: from batch C**, developer and reviewer agents run `lane submit` / `lane review` under their packet's principal; the operator still admits, issues packets and integrates |
| Q9 | Start budget for the store seeded at the ML-RENAME-DOMAIN-TAGS rotation | **Decided 2026-09-24: 50 developer / 50 reviewer starts** (`lane-policy.example.json`), so batch C can run about four developers in parallel; a policy-revision command stays deferred until that runs out |
| Q10 | Keep dated records (`docs/archive`, fr-08 evidence) in the tree? | **Decided 2026-09-24: no.** Tag `records/2026-09-24` at `b30d0a2` (the last commit before the renames, so the records keep their original names), delete `docs/archive`, and turn inbound links into permalinks at the tag. `docs/fr-08` gets the same treatment in batch C's triage; reviews and this log stay. Supersedes Q6 for those records |
| Q11 | Is FR-18A (bounded effect queries, the `Observations` module) still live? | **Decided 2026-09-24 (operator deferred to the recommendation): keep.** The plan lists it in progress; its `:legacy` branch goes with the legacy-tables ticket |
| Q12 | Tools for precise, cheaper agent work | **Decided 2026-09-24:** add `boundary` and `sourceror` (Hex, locked), use `mix xref` / `mix xref graph` and compiled `debug_info` checks, and an Elixir outline script; ticket ML-PRECISION-TOOLING opens batch C2. `AGENTS.md` now says how to search code |
| Q13 | Is Foundry still scoped to "one operator, one machine, Pramāṇa", and must status go to Pramāṇa's `docs/PLAN.md`? | **Decided 2026-09-25: no to both.** Foundry is fully decoupled from Pramāṇa: the repair plan's scope clause and completion requirement are rewritten, and no document links to Pramāṇa pages. Trust in a new operator, host or repository still waits on FR-15aB. Follow-ups the same day: the post-repair tracks are re-filed here as [#15](https://github.com/lorecrafting/foundry/issues/15) and [#16](https://github.com/lorecrafting/foundry/issues/16), the Pramāṇa-era meta-harness note moved to the records tag, and the dead `COORDINATOR_TICK`/`HERDR_ENV` scrubbing left `ci.ex` and its tests. The docs branch was reviewed outside the lane ([review 1](reviews/DOCS-FRONT-DOOR.review-1.md), correction, folded in; [review 2](reviews/DOCS-FRONT-DOOR.review-2.md), approved), and so was the revision-4 R3 contract paragraph ([review](reviews/CONTRACT-R3.review.md), PASS WITH CHANGES, folded in) |
| Q14 | Should R4 state the kernel's stricter reading, that a review verdict is recorded only after the reviewer stream is sealed? | **Open.** The [R3 review](reviews/CONTRACT-R3.review.md) F2 found the kernel enforces it (`review.ex` `require_reviewer_stream_sealed/1`) while R4's rows list the seal as an outcome of the verdict. Adding it is a one-line R4 edit and an operator decision |
| Q15 | C2 review models, Ponytail, docs and test discipline | **Decided 2026-09-26 by the human:** use OpenAI models only while Claude Code is unavailable; choose model by task complexity and use a different model for independent review. Install Ponytail for Codex and require its developer self-review in standing briefs. Add a docs Ponytail (800-word `AGENTS.md` cap and milestone tidy pass) to ML-PRECISION-TOOLING. Adapt Lokacore's test guidance so every new test has a distinct plausible regression, independent expected answer and demonstrated red control where required; keep fixtures and test count lean. Put pinned `ast-grep` CI lints in a separate follow-up ticket. Open visible GitHub PRs for batch CI, then fast-forward locally rather than merge on GitHub. Same-vendor model review is weaker independence than cross-vendor review (risk A3) |
| Q16 | Gateway split's open design choices | **Decided 2026-09-26 by the human:** use the [Gateway design](../design/DECOMPOSE-GATEWAY.md#8-operator-questions-recorded-not-decided) defaults: pin `Maintenance` in FR-08A, retain the `Gateway` delegate for the ProtectedPrimitives back-edge, and defer T3's semantic deletion of legacy protected inserts to its own reviewed ticket. Q15/Q12 already keep the shared move checker in `bin/` |
| Q17 | Speed of the Protected Primitives split | **Decided 2026-09-26 by the human:** use grouped mechanical moves verified as they land, focused checks during the split, one independent review and one FR-08A rebind on the integrated tip. Keep semantic cleanup, including legacy deletion, in separate reviewed work. The 9 → 19 pin-list growth means one rebind with more pinned files, not a rebind after each move |
| Q18 | Protected Primitives design's remaining open questions | **Decided 2026-09-26 by the human:** keep the facade through this ticket and decide delegate removal separately; amend FR-23 acceptance to allow one rebind on each integrated split tip; pin the seven named `Protected.*` modules; retain the shared move checker in `bin/`; keep `Operations` whole; use `Protected.*` files in a subdirectory. These are the proposed defaults in [the design §7](../design/DECOMPOSE-PROTECTED-PRIMITIVES.md#7-risks-and-open-questions-recorded-not-decided), approved together before implementation |
| Q19 | First product milestone and value test | **Decided 2026-09-26 by the human:** pivot after the C2 god-module decompositions to [portable governed acceptance](../REPAIR-PLAN.md#delivery-sequence-portable-governance-first). Codex, Claude Code and other clients orchestrate; Foundry provides authenticated durable provenance, exact evidence and acceptance through CLI/MCP. Defer Foundry-run launch, scheduling, billing, session recovery, Pi harness and bundled reference controller until measured need. Use real LokaCore work to compare against the ordinary native-client workflow, including operator effort and false blocks; retain controlled refusal drills. The human clarified that Gateway and Protected Primitives decomposition still proceeds in C2. Request an independent Astra review of the reprioritization before landing it |
| Q20 | Evaluation repository | **Decided 2026-09-26 by the human:** evaluate Foundry's usefulness while building Foundry, using prospectively matched internal tickets and the ordinary native-client workflow as the comparison. Keep LokaCore separate for now. Revise ML-PG-EVALUATION and its validation protocol; Q19's LokaCore pilot target is superseded, while the portable-governance milestone and C2 decompositions remain. Independent [review 1](reviews/FOUNDRY-EVALUATION.review-1.md) required an observed-acceptance numerator; [review 2](reviews/FOUNDRY-EVALUATION.review-2.md) approved the correction |
| Q21 | Pi, Codex and Claude Code integration timing | **Decided 2026-09-26 by the human:** record a Foundry plugin/client deliverable for all three hosts. [ML-PG-CLIENTS](https://github.com/lorecrafting/foundry/issues/19) follows protected acceptance and precedes evaluation; Pi may join the current manual lane earlier as an ordinary agent without a governed-integration claim. Share the Foundry protocol and skill; keep host packaging thin and prove real client conformance before claiming portability. No host hook or plugin grants Foundry authority |
| Q22 | Where to hold the authoritative accepted Git ref for the first milestone | **Operator default 2026-09-26 under the human's continue-without-input instruction:** choose a dedicated local bare repository owned by the protected service under an actual OS access boundary, as [reviewed](reviews/ML-PG-CONTRACT.review-2.md). It is the smallest first proof of exclusive writing. CUSTODY must verify that agents/check workers cannot write it and record the operator-selected initial commit at provisioning. No repository was provisioned by the design ticket. A remote Git host may be supported later only if its exclusive credentials and expected-old atomic update are proved |
| Q23 | Who may submit a protected review verdict in the first milestone | **Historical default, superseded by the human's autonomous-first decision below only after independent amendment approval and real-host gates.** **Operator default 2026-09-26 under the human's continue-without-input instruction:** a separate trusted human reviewer account inspects the candidate, check facts and untrusted agent-drafted notes, then submits the verdict. An agent reviewer has no verdict credential while candidate tools can run under its UID. Agent self-submission is deferred until a client adapter proves tool/process separation. This narrows the new protected route only; current manual-lane Q8 remains its historical workflow. Count the extra human work in ML-PG-EVALUATION. The [custody design](../design/PORTABLE-CUSTODY.md) and [plan](../REPAIR-PLAN.md#delivery-sequence-portable-governance-first) record the limit |
| Q24 | Autonomous reviewer and ordinary promotion first | **Human decision 2026-09-26:** choose agent reviewer submission through a generic authenticated scoped attestation capability under separate attestation-only OS/process authority, with no candidate-executing tool in that authority, and preauthorized protected exact-ref CAS promotion for ordinary accepted work instead of a trusted human verdict or promotion click for every ticket. [Amendment](../design/PORTABLE-AUTONOMOUS-REVIEW.md) received [full-range independent design-only approval](reviews/ML-PG-AUTONOMOUS-REVIEW-ROLE-AGNOSTIC.review-1.md) at `92d678a`; review-only broker and macOS/Linux real hostile-tool, useful-positive and restart proof must still pass before enabling. The earlier `cfb2de8` approval remains historical under its older criteria and cannot substitute for the new full-range review. Software workflow/policy own role names and qualifying verdict semantics; protected Core checks principal/lineage and pinned facts without a reviewer-specific operation or widened boundary rule 3. Q23 remains historical, not permission to approve an immutable old-criteria custody packet; re-admit with fresh review. Root/policy upgrades remain operator-maintained and unknown holds do not auto-clear. Same-provider reviewer independence and prompt-injection risks remain disclosed |
| Q25 | How to eliminate the packet-provenance custody/candidate/reviewer acceptance cycle without dropping custody proof | **Operator sequence decision 2026-09-27, independently [approved—design only](reviews/ML-PG-MILESTONE-SEQUENCE-DESIGN.review-1.md) at `8f9c26f`; not implementation approval:** adopt the [acyclic table](../REPAIR-PLAN.md#portable-milestone-tickets-in-dependency-order): separately admit CUSTODY-FOUNDATION → CANDIDATE → REVIEW-BROKER → CUSTODY-CLOSURE → ACCEPTANCE → CLIENTS → EVALUATION, with operator-admitted protected contract/spec/policy, independent design and exact-candidate implementation reviews at each boundary. Foundation proves actual operator/developer isolation, original atomic packet and authenticated producer seal with useful developer positive and restart, **not** a reviewer packet or full custody. Candidate independently imports/checks against that seal without broker. Broker requires immutable import for the reviewer packet and real isolated agent positive; closure retains every remaining original isolation, reviewer hostile-tool, revocation, replay and restart obligation without treating the old human-verdict ML-PG-CUSTODY packet as re-admitted. Q24 supersedes human-per-ticket positive prospectively, not host trust evidence. Independent [packet-provenance review 1](reviews/ML-PG-PACKET-PROVENANCE-DESIGN.review-1.md) recorded correction (P1 cycle and P1 consumer selection); [full-range review 2](reviews/ML-PG-PACKET-PROVENANCE-DESIGN.review-2.md) approved the corrected `a86ebce` **design only** after Q25 landed. The earlier `/private/tmp/ML-PG-PACKET-PROVENANCE-ORDER-DECISION.md` was operator proposal/data, not authority; protected spec/contract and consumer-selection code still need independent implementation review before foundation Core work. **Gate/disposition:** no protected implementation admission from this document alone, no enabled agent verdict/promotion until closure and acceptance host proof; old packet and missing results stay historical/held, unknown revoked issuers keep holds and no terminal non-start without independently reviewed non-delivery/quiescence evidence and typed R4a handoff. Human administrator macOS/Linux provisioning and real hostile-tool, useful-positive, restart and scratch red controls remain required. Frozen workflow contract/reviews unchanged |

## Frictions

| # | Where | What happened | Candidate fix |
|---|---|---|---|
| F1 | `bin/foundry lane …` | Every command prints the daemon's `[info] lane <cmd> started/finished` log lines around its result, so output needs filtering before it can be read or parsed | keep lane command logging off the RPC client's stdout, or only at debug |
| F2 | `.github/workflows/foundry-ci.yml`, AGENTS.md | CI runs only on pushes to `main` and on pull requests, but AGENTS.md said every push; a pushed branch got no run, so Linux CI needs a PR before `main` moves | AGENTS.md corrected; operator opens a PR per integration batch |
| F3 | GitHub CI | The handoff expected one known Linux failure; there were 107 (hardcoded `/private/tmp`, `/bin/zsh`). Linux runs 1229 tests against macOS's 1232: the three darwin-only filesystem tests in `operational_storage_test.exs:489` | fixed in `f8e6b44`; conventions now forbid both |
| F4 | reviewer briefs | Reviewers ran tests in the developer's candidate worktree; one used `git checkout -- .` for a red control (brief forbids it). Nothing uncommitted was lost, but a reviewer can alter the checkout the lane recorded | give each reviewer its own detached worktree at the candidate |
| F5 | `lane review --notes` | The store keeps only the notes' digest; the notes file lives in `/private/tmp` and would be lost | operator copies notes into `docs/batch-d/reviews/`; the lane could archive the notes body |
| F6 | lane end state | Nothing records `integrated` (risk A5): after cherry-pick, `lane status` still says `ready_to_integrate`, and the integrated SHA lives only in this log | an `integrate` command recording the main SHA |
| F7 | lane policy | The seed grants 10 developer and 10 reviewer starts for the whole store, with no way to add more: after batch 1 and batch A1, 5 remain, and the campaign needs about 10 more. Small tickets were merged to save starts. **It bit:** ML-PROCESS-GROUP-TESTS got a one-line `correction`, and `lane packet` refused the correction attempt with `allocation_unavailable`; the ticket carries over to a fresh store as ML-PROCESS-GROUP-TESTS-2 rather than bypassing the lane | a policy-revision command that raises starts, or a runbook step for rotating the store |
| F8 | `lane admit --scope` | Scope is fixed at admission; ML-DEL-LEAVES found `relocation_containment_test.exs` outside it. The only choices are an out-of-scope edit the reviewer must accept, or abandoning the ticket and admitting a new one | a scope amendment recorded as its own event before the packet is issued |
| F9 | reviewer run | The first ML-DEL-DAEMON reviewer died on an API rate limit mid-review. The lane has no record of it; a fresh agent reused the issued reviewer principal, so one principal named two model instances (risk A3). Reviewers now write notes early so a crash leaves partial findings | a `lane packet --role reviewer` re-issue that records the replacement instance |
| F10 | integration | **Operator error.** The ML-DEL-DAEMON correction had two commits; I cherry-picked only the candidate SHA's own commit (`742a60d`), so the reviewed `:stale_identity` tests and knowledge additions (`12aff6c`) missed batch A1 and its gate. Caught by `git cherry main <dev branch>` during worktree cleanup; landed afterwards with its own gate | integrate the range `<previous candidate or base>..<candidate>`, and check `git cherry` is empty before calling a ticket integrated; `lane integrate` (F6) could check candidate ancestry in main |
| F11 | test hygiene | A peer Pramāṇa session reported that `process_group_test`'s zombie fixture leaks an orphaned Python helper on every run (98 found on the operator's Mac); confirmed, 3 from this session's gate | ticket ML-PROCESS-GROUP-TESTS, with the flake the ML-DEL-DAEMON rereview found |
| F12 | expected-red tests and unrun pins | While a protected change awaits the operator's FR-08A rebind, `fr08a_protected_boundary_test` is expected red, and that masked a real failure in the same file: the identity-negative fixture still asserted 7 capabilities. Neither the developer nor the reviewer could tell the two apart. The batch gate then caught a second miss from the same ticket: `ci_test.exs:65` pinned the `fetch-depth: 0` the ticket removed, and nobody ran `ci_test`. Both were fixed in operator integration commits | developer briefs: run the FR-08A test after a scratch rebind in a throwaway worktree, so only real failures remain red; and grep `test/` for every string a ticket deletes from config or workflows |
| F13 | `lane integrated` refusal | An unknown ticket prints `refused` / `detail: -` without the refusal atom the runbook promises (`error: <atom>`) | print the atom like every other refusal |
| F14 | `lane submit` | The candidate must be the checkout's `HEAD`. To drop a developer's trailing commit (it broke 62 permalinks), the operator had to `reset --hard` the developer's own worktree before submitting | let `submit` take a candidate that is an ancestor of a clean checkout's `HEAD`, or brief developers to leave optional commits on a side branch |
| F15 | renaming the release | After the release rename, `bin/foundry-lane` and `bin/…` look for `rel/foundry` and cannot reach or stop the running daemon built as the old release. Order: `lane integrated`, stop the daemon with the old scripts, fast-forward `main`, rebuild, start | runbook step for tickets that change the release or RPC entry |
| F16 | operator integration worktree | **Operator error.** A `deps` symlink in the integration worktree made the gate refuse `{:dirty_source, ["?? deps"]}` (`.gitignore`'s `/deps/` does not match a symlink). Cost one gate start | never symlink deps into a gated tree; use `MIX_DEPS_PATH` |
| F17 | refusals | Every refused lane command also prints an Elixir `RuntimeError` stack trace from `cli.ex:86` on stderr; stdout and the exit code are right | print the refusal and exit non-zero without raising |
| F18 | `bin/check_docs.exs` | It resolves links against tracked files only, so a link to a newly copied, unstaged review file reads as broken (hit twice) | `git add` before `check_docs`, or check the working tree |
| F19 | usage limits | A shared API session limit killed both running developers and a reviewer at once. The lane recorded nothing: the tickets sat in `active` and `reviewing`. Resuming the same agent instances after the reset lost no work and kept one principal per instance (compare F9) | the operator checks `lane status` and worktrees after any limit; run fewer agents at once when the budget is tight |
| F20 | new move tooling | The first ML-PRECISION-TOOLING candidate's focused suite was green, but independent review reproduced four unsafe or falsely reassuring paths: piped callers, alias shadowing/chains, a wrong split-set call target accepted by the compiled checker, and source modification before a failed destination write. One capture-form defect had already been caught by the developer's red control. The second review found four more gaps despite 24 focused tests; the third found two more despite 27 focused tests. Cost so far: three correction rounds before either decomposition can use the tools | add each realistic failure as a controlled regression, fix or conservatively refuse it, and have a new reviewer probe the corrected candidate before integration |
| F21 | model-specific brief | `docs/AGENT-BRIEF.md` still named Fable as the required independent reviewer after Q15 switched this campaign to OpenAI-only models; independent review found it in the first C2 candidate. Cost: a documentation correction and risk that a future operator would pause unnecessarily | make the standing rule fresh/different-model, record same-vendor independence limitation, and name the chosen principal only in each ticket's brief |
| F22 | local lane access under managed sandbox | After the session's sandbox profile changed, a read-only `bin/foundry lane status` and the reviewer's `lane review` initially failed with `Protocol 'inet_tcp': register/listen error: eperm`; the local Erlang distribution needs sandbox escalation. Cost: delayed recording the second verdict | use the command approval path for lane RPC under this sandbox; confirm the store receipt rather than treating a written review file as recorded |

## Scorecard

Is the lane worth running? One row per ticket, filled at integration. **Caught** = defects a
review found (H/M/L); **escaped** = defects the review passed that a rebind, gate or CI then
found; **rounds** = reviews to approval; **lane caught / blocked** = refusals that stopped a
real error / refusals that stopped legitimate work. Frictions: F1–F13 in store 1's nine tickets,
F14–F16 in store 2's first two.

| Ticket | Rounds | Caught | Escaped | Lane caught / blocked |
|---|---|---|---|---|
| ML-CONTRACT-DIVERGENCES | 1 | 0 | 0 | 0 / 0 |
| ML-RUNTIME-PATHS | 1 | 1 L (Q2) | 0 | 0 / 0 |
| ML-WORKFLOW-DIR | 1 | 1 L (Q3) | 0 | 0 / 0 |
| ML-DEL-DAEMON | 2 | 1 H (a guard lost its only test), 1 M (pre-existing flake) | 0 | 0 / 0 |
| ML-DEL-LEAVES | 1 | 1 L (out-of-scope edit, F8) | 0 | 0 / 0 |
| ML-DEL-LEGACY-IMPORT | 1 | 0 | 2 (F12: identity-negative fixture, `ci_test` pin) | 0 / 0 |
| ML-DOCS-ARCHIVE | 1 | 0 | 0 | 0 / 0 |
| ML-LANE-FRICTIONS | 1 | 0 | 0 | 0 / 0 |
| ML-PROCESS-GROUP-TESTS | 1, then carried over | 1 L (stale safety comment) | 0 | 0 / 1 (`allocation_unavailable`, F7) |
| ML-PROCESS-GROUP-TESTS-2 | 1 | 0 | 0 | 0 / 0 |
| ML-RENAME-NS | 2 | 1 L (tautologies) | 0 | 0 / 0 |
| ML-RENAME-BIN-ENV | 1 | 0 (3 informational notes) | 0 | 0 / 0 |
| ML-DOCS-ARCHIVE-DROP | 1 | 0 (2 pre-existing stale prose paths) | 0 | 0 / 0 |
| ML-RENAME-DOMAIN-TAGS | 1 | 0 (2 doc nits) | 0 | 0 / 0 |
| ML-FR08-TRIAGE | 1 | 0 | 0 | 0 / 0 |
| ML-LANE-FRICTIONS-2 | 1 | 0 (2 notes) | 0 | 1 / 0 (short-SHA `submit` refused) |
| ML-DEAD-VOCAB(-2) | 1 | 0 (3 minor notes) | 0 | 0 / 1 (`blocked` terminal; re-admitted, F8) |
| ML-GATE-EVIDENCE-TOOLS | 1 | 0 (3 low notes) | 0 | 0 / 0 |
| ML-DEAD-ROUTES | 1 | 0 (1 follow-up) | 0 | 0 / 0 |
| ML-DECOMPOSE-GATEWAY-DESIGN | 2 | 2 H (rebind leaves FR-08A red; move check blind to aliases), 4 L | 0 | 0 / 0 |
| ML-DECOMPOSE-PP-DESIGN | 3 | 3 H (unfenced write primitives; alias collisions; rule 13 vs pins), 2 M | 0 | 0 / 0 |
| ML-QUINT-CITATIONS | 1 | 0 | 0 | 0 / 0 |
| ML-PG-CONTRACT | 2 | 2 H (accepted-base equality; promotion exclusion) | 0 | 0 / 0 |
| ML-PG-CUSTODY-DESIGN | 3 | 2 H (reviewer tools; privileged file paths), 2 M (UID reuse; retry ordering) | 0 | 0 / 0 |
| ML-PG-CUSTODY-RECONCILIATION-DESIGN | 2 | 1 H (lost packet result deferred instead of designed) | 0 in local gate | 0 / 0 |

**Reading, 2026-09-24 (11 tickets, before ML-RENAME-BIN-ENV).** Independent review pays: 7 defects caught, one of them
high, against 2 escapes. The lane itself has caught no real error yet and has blocked one
legitimate step. That is expected while the operator runs every lane command: the lane has
been a trail, not a boundary. Frictions have not fallen (three in store 2's first two tickets),
and nearly all sit at the manual edges (submit, integration, store rotation), not in Core.

**Changes from batch C (operator decision Q8):** developer and reviewer agents run their own
`lane submit` and `lane review` under their packet's principal, so the principal and
independence rules are exercised against the agents; and failure drills (below) test whether the
lane refuses or only records. Judge again after batch C.

## Drills

| # | Drill | Expected | Observed |
|---|---|---|---|
| D1 | `submit` by a principal that did not issue the packet | refuse | `receipt_provenance_mismatch` ✓ |
| D2 | reviewer packet before any submit | refuse | `wrong_source_phase` ✓ |
| D3 | `submit` from a dirty checkout | refuse | `git_evidence`, names the modified file ✓ |
| D4 | candidate that only touches a file outside `scope` | accepted (A4: scope unchecked) | accepted, `awaiting_review` — record only; the reviewer is the only scope check |
| D5 | the developer principal asks for the reviewer packet | refuse | `principal_not_independent` ✓ |
| D6 | a principal other than the reviewer packet's issuer records the review | refuse | `receipt_provenance_mismatch` ✓ |
| D7 | review names a candidate other than the submitted one | refuse | `candidate_mismatch` ✓ |
| D8 | `kill -9` the daemon while a reviewer packet is issued, restart | fenced until attested recovery | every command refused with `ambiguous_previous_owner` and the next step; `recover --evidence` → `ready`; ticket state intact ✓ |
| D9 | use the pre-crash reviewer packet after recovery | works | review recorded (`rejected`) ✓; a second review → `review_already_recorded` ✓ |

Drills ran 2026-09-24 on throwaway ticket ML-DRILL-1 in store 2 (rejected, never integrated).
Every refusal also prints an Elixir `RuntimeError` stack trace on stderr (F17); stdout and the
exit code are clean. D4 is the lane's one gap exercised here, and D1/D6 show the principal check
works only because principals are self-declared strings (A3): an impostor who types the right
principal passes.
