# C9 independent end-of-batch re-sweep

**Reviewed:** `4520c585371e1e743c42a0382f0fcbc4f5d1d79b`
**Checkout:** `/private/tmp/foundry-C9-packet-provenance-resweep`
Read-only assessment, **not a lane verdict or landing authorization**.

## Review

- **Correct — scope and semantic preservation.** Read both supplied committed diffs completely: full range, lines 1–229; post-ancestry-merge delta, lines 1–210, including both truncated continuations. Only six documentation paths change. The operator delta changes packet-design status/context and the Q23/Q24 attribution, not its substantive protocol. No source, tests, frozen contract or boundary allowlist changes.
- **Correct — no restored acceptance cycle.** `docs/REPAIR-PLAN.md:178–182` and `docs/design/PORTABLE-PACKET-PROVENANCE.md:19` retain FOUNDATION developer positive → CANDIDATE import/check positive → BROKER agent positive → CLOSURE → ACCEPTANCE. Foundation forbids reviewer issuance; import needs neither broker nor completed closure. Closure retains all remaining original custody obligations.
- **Correct — authoritative consumer and producer sources.** `docs/design/PORTABLE-PACKET-PROVENANCE.md:9,15–17,25,29–34` fixes one operator-admitted consumer key before producer creation, carries it through seal/import/issue/reopen, and requires exhaustive protected/domain producer enumeration. The X=[A], Y=[A,B] counterexample cannot select X to omit existing B. Missing/ambiguous admission, incompatible producers and unselected consumers refuse.
- **Correct — no premature implementation claim.** `docs/REPAIR-PLAN.md:168–177` expressly retains separate original-packet binding review and implementation gates. Existing `lib/foundry/work_packet.ex:23–61` still depends on active-attempt/issued-claim facts; `lib/foundry/manual_lane/backend.ex:465–490` reconstructs packets and filters issuer lookups. Neither is the proposed historical protected seal. `docs/design/PORTABLE-PACKET-PROVENANCE.md:11,19,30` retains nonempty-check-schema and terminal non-start limitations.
- **Correct — C8 evidence remains ref-specific.** `docs/batch-d/DOGFOOD-LOG.md:104,230` agrees with the C8 provenance and `/private/tmp/foundry-C8-main-push-evidence.md`: local gate at clean `ab7f6cd`; PR run `36308020588` and main-push run `36308408054` at that same head. The reported counts remain 812 local versus 809 Linux, not custody acceptance.
- **Correct — historical attribution is preserved.** The saved lane log records correction event 389 for `4b78bb4` and approval event 409 for `a86ebce`, with distinct Astra review principals and the same Sol developer. Committed review text agrees with the embedded notes; the approval archive also agrees on inspection. Recorded note digests are:
  - Correction: `ec40c0ef48158a863df925b82b76652e71664b41a9be01de16d8645b7f27f733`
  - Approval: `18e19ba9ae5baf185c2d1f9e0101e7ffeaa5c84820ebaa5e3fbd9e9815d844e0`

### Ranked actionable finding

**P2 — C9 live handoff still calls completed gate/PR checks pending.**

`docs/batch-d/DOGFOOD-LOG.md:106,108,229` says “Gate, PR CI … pending,” “finish C9 operator gate, Linux PR CI,” and “gate/PR pending.”

The supplied C9 provenance records `passed`, clean pre/post source and exact `4520c585371e1e743c42a0382f0fcbc4f5d1d79b`. The task separately supplies passing exact-tip PR #28 Linux run `36309387675`, 809 tests.

**Smallest fix:** update those three live status locations in the next operator evidence follow-up, recording the exact gate ref/provenance and PR run. Record landing and main-push results only from separately verified evidence. Do not rerun the gate merely for this stale wording or transfer its pass to a later documentation tip.

**Merge verdict: OK with notes** for this bounded documentation review. No P0/P1 finding. Parent retains landing and fixes.

## Separate Ponytail complexity check

Lean enough: one immutable consumer key, a finite contract and existing transaction/read-set patterns address concrete provenance gaps. No graph interpreter, formatter callback, second authority store or bootstrap bypass is introduced. Exhaustive history and current-access checks are necessary safeguards, not removable complexity.

## Evidence and limitations

- Worktree metadata contains the exact detached HEAD; `watchdog_diff` reports no working-tree changes before and after review.
- Read AGENTS, README/index, current milestone plan/handoff/Q24–Q25, packet design, correction/approval notes, reviewed C8 sequence, custody/reconciliation/autonomous designs and relevant source seams.
- Ancestry integration and merge-tree equality remain parent-provided evidence; not independently recomputed. Digest values were checked for documentary consistency, **not freshly hashed**.
- C9 provenance confirms the passing gate; **812 tests** is the supplied count. PR success/count is task-provided evidence, not a fresh CI query.
- Main-push run `36309765370` was pending at task issue; **no result inferred**.
- No shell, edits, checks, host/CI calls or lane commands ran. Protected implementation, nonempty-check schema, non-delivery/quiescence proof with typed R4a handoff, and actual macOS/Linux isolation/restart/red controls remain outstanding. Same-provider correlated judgment and prompt injection remain risks.