# C11 end-of-batch independent re-sweep

**Result:** no new P0/P1/P2 finding or blocking design regression. One new P3 live-documentation finding; the previously recorded P3 deployment note remains. This is an end-of-batch report, **not a new manual-lane verdict or receipt**, implementation approval, or host-enablement decision.

## Identity and scope

- Verified detached, clean HEAD `e0d4867e26bd090b8e292d0c79e4da63a893f7cd` before and after review.
- Reviewed the complete `50aa40bc53429c4b0d2daddc715f379d7e2d8b4b..e0d4867e26bd090b8e292d0c79e4da63a893f7cd` range: five documentation files, +173/-2: `docs/design/PORTABLE-CUSTODY-OPERATOR-INGRESS.md`, `docs/batch-d/reviews/ML-PG-CUSTODY-OPERATOR-INPUT-DESIGN.review-1.md`, `docs/batch-d/DOGFOOD-LOG.md`, `docs/REPAIR-PLAN.md`, and `docs/README.md`.
- Compared the full approved ticket `50aa40b..9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9` with integration. The complete tree at `d796a66` equals the approved candidate tree. The subsequent `e0d4867` changes record review/status only; the ingress mechanism is unchanged.
- Applied `docs/AGENT-BRIEF.md`, boundary rules, repair plan, lane runbook and operator-loop step 8; read the governing custody, reconciliation, autonomous-review, provenance and packet-binding designs.

## Ranked findings

### 1. P3 — Refresh the live C11 landing handoff

**`docs/batch-d/DOGFOOD-LOG.md:110` and `docs/batch-d/DOGFOOD-LOG.md:235`.** The current handoff still says C11 local gate, PR CI and main landing are pending, and the ticket row stops at `d796a66` with “gate/PR pending,” although this review was commissioned on final main `e0d4867` after PR #30. This leaves the next operator with stale delivery state and no final-tip evidence reference.

**Action:** add a current completion entry/link and update the ticket row using separately verified exact-SHA local-gate/PR/main receipts. Preserve the earlier handoff as historical if desired; do not rewrite the immutable ticket review. I did not independently query CI or rerun the gate, so this finding does not assert any uninspected check passed.

### Carried forward, not newly discovered: P3 — sshd directive placement

**`docs/design/PORTABLE-CUSTODY-OPERATOR-INGRESS.md:29`; historical finding at `docs/batch-d/reviews/ML-PG-CUSTODY-OPERATOR-INPUT-DESIGN.review-1.md:15–19`.** Do not translate all described controls into one `Match User` block: `PermitUserEnvironment` is global-only on the previously inspected OpenSSH. The live handoff and plan explicitly retain this note. Clarify the eventual deployment recipe and verify effective installed configuration; this is not a new authentication blocker or host proof.

## Correctness and adversarial review

- **Authentication/input:** the design distinguishes the internal Gateway capability from operator authorization. Dedicated service/store, peer credentials, current maintenance entitlement and transactional CAS remain required. Reading the existing Gateway, manual Server/context, Backend, Replay and release wrapper corroborates why the present manual lane cannot authenticate protected operator admission. A schema-valid developer request cannot obtain the proposed operator peer merely by invoking a root queue, remote command or local executable: the selected authenticator is a separately held SSH key/session, followed by complete canonical display/confirmation and frozen bytes. Shared keys, agent-writable input and unproved PTY controls explicitly disable admission. SSH/PTY is not claimed to prove human fingers.
- **FD acquisition:** the historical transferred-FD refusal is not resurrected. Deliberate trusted transfer delegates authority; accidental acquisition remains in scope. Fork/exec before connect, no descendants/helpers/SCM_RIGHTS afterward, private service FDs and real debugger/descriptor/IPC denial are explicit requirements. CLOEXEC, enrollment checks and generation are not presented as a cure for a current authorized transferred stream.
- **Revocation/restart/unknown:** every read/write checks current authorization; exact authorized retries compare original complete request and return durable historical results without rerunning stale mutation CAS. Restart invalidates old connections, not authenticated historical results. Missing/conflicting history fences readiness; unknown stays held.
- **Original packet provenance:** protected admission cannot be backfilled from manual tickets or mutable controller reads. The existing atomic result/seal design remains authoritative, including complete intent/history, selected consumer, protected producer lineage and installation/store binding. No seal certifies Git/checks; no `policy_empty` fiction, synthetic terminal non-start or early reviewer positive is introduced.
- **Live versus historical claims:** design status, index, repair plan, Q27 and Next handoff consistently say design-only, unimplemented and untested on installed hosts. The earlier two P1 corrections remain historical corrections. The checked-in review's approval and scratch probes do not become current code/host evidence. No live changed document falsely grants protected enablement.

## Separate Ponytail review

The bounded docs-only change reuses OpenSSH, OS credentials, the existing internal capability and the reviewed packet transaction rather than inventing another bearer-token or packet-storage framework. No dependency, speculative implementation or broader Core change was added. The long attack/acceptance lists cover distinct trust failures; shortening them by dropping input provenance or FD acquisition would remove requirements, not useful complexity.

## Checks and limitations

- `git diff --check 50aa40b..HEAD`: passed.
- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS.md **469/800 words**.
- `git diff --quiet 9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9 d796a66`: passed, identical complete trees.
- Owned, single-UID Python PTY probe: `/dev/tty` opened with `O_NOFOLLOW`, foreground check true. On this macOS host its alias was root-owned while the real PTY slave was UID 501, with different device numbers. Implementation must validate the actual controlling PTY rather than equate the alias's `fstat` owner/device with the slave. This is a deployment precision observation, not a demonstrated design bypass or installed-host test.
- Final checkout remained detached and clean, including index and untracked-file inventory. Only this external report was written.
- No full gate, test-suite mutation, FR-08A rebind, manual-lane command, sudo/provisioning or protected admission was run. Prior reviewer parser/red probes remain attributed historical evidence, not rerun evidence.
- Real distinct-UID macOS/Linux installation, useful operator/developer positives, hostile input/FD acquisition, revocation, lost reply/reopen and independent red controls remain outstanding. No protected route may be enabled on this report; Foundation's stated host-boundary blocker remains.

```acceptance-report
{
  "criteriaSatisfied": [{"id":"criterion-1","status":"satisfied","evidence":"Complete five-file batch range and exact approved-candidate integration compared; one new P3 live-handoff finding, carried-forward P3 and host limitations recorded."}],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {"command":"git rev-parse HEAD; git status --porcelain=v1; detached/index/untracked checks","result":"passed","summary":"Exact e0d4867e26bd090b8e292d0c79e4da63a893f7cd; detached clean checkout before and after."},
    {"command":"git diff --quiet 9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9 d796a66","result":"passed","summary":"Approved candidate and three-commit integration have identical complete trees."},
    {"command":"git diff --check 50aa40b..HEAD","result":"passed","summary":"No whitespace errors."},
    {"command":"elixir bin/check_docs.exs","result":"passed","summary":"0 broken links; AGENTS.md 469/800 words."},
    {"command":"Owned Python PTY alias/foreground probe","result":"passed","summary":"Foreground controlling terminal available; root-owned /dev/tty alias differs from UID-501 PTY slave. Not isolation evidence."},
    {"command":"Full gate, FR-08A rebind, manual-lane review and installed-host acceptance","result":"not-run","summary":"Excluded from this separate read-only end-of-batch re-sweep."}
  ],
  "validationOutput": ["No new P0/P1/P2 finding or blocking design regression.","Five documentation files reviewed, +173/-2; implementation untouched."],
  "residualRisks": ["Installed distinct-UID macOS/Linux input, FD, revocation, restart and red-control gates remain unrun.","Current C11 handoff lacks final landing/evidence update; CI and local-gate outcomes were not independently queried.","Global-only sshd environment controls and actual PTY-slave validation require care in implementation."],
  "noStagedFiles": true,
  "diffSummary": "Read-only review of the complete C11 documentation range; no checkout changes.",
  "reviewFindings": ["P3: docs/batch-d/DOGFOOD-LOG.md:110,235 — refresh live C11 pending landing/evidence status.","Carried-forward P3: docs/design/PORTABLE-CUSTODY-OPERATOR-INGRESS.md:29 — distinguish global sshd directives from Match controls.","No new P0/P1/P2 findings."],
  "manualNotes": "Separate end-of-batch re-sweep, not a new manual-lane receipt. Historical review preserved; no protected implementation or host enablement approved. External artifact: /private/tmp/foundry-C11-batch-resweep.md."
}
```
