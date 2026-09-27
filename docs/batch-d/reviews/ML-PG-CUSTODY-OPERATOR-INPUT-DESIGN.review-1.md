# ML-PG-CUSTODY-OPERATOR-INPUT-DESIGN — independent review 1

**Verdict: APPROVED — design only. No blocking design finding. One P3 deployment-precision note.** This does not approve an implementation, authenticate today's manual lane, authorize sudo/provisioning, or enable protected admission. Historical ingress and topology verdicts remain CORRECTION.

- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-CUSTODY-OPERATOR-INPUT-DESIGN-1`.
- Packet: `/private/tmp/ML-PG-CUSTODY-OPERATOR-INPUT-DESIGN.review-1.json`.
- Complete reviewed range: `50aa40bc53429c4b0d2daddc715f379d7e2d8b4b..9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9`.
- Three commits: `bf5a5bffbb97e5772036b7b71d578f05c975de59`, `c296dabbb5b2f51b8eb90b0c0a7dd6eac14bacea`, `9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9`.
- Own detached worktree: `/private/tmp/ML-PG-CUSTODY-OPERATOR-INPUT-DESIGN-review-1`; exact clean candidate verified before and after checks. No staged files or candidate edits.
- Scope exactly matches the four packet paths: ingress design, docs index, repair plan, dogfood log; +61/-2 overall. First and second range commit trees independently equal historical `553c62b` and `06cef19` trees respectively.
- Read both exact archived P1 notes and independently matched SHA-256 filenames `29b43efa7f26c2dab87da24638c34f41d94911326ac7fc308f09df25e8f0d5e3` and `51fed0398f06911205c86232aaacb3caeb91cab2225841739a87c3d23cc119f3`.

## Ranked findings

### P3 — Distinguish global sshd environment controls from Match-legal controls

`docs/design/PORTABLE-CUSTODY-OPERATOR-INGRESS.md:29` compresses the installed controls into a “Match User sshd configuration.” Do not translate that literally into putting every directive inside Match: **`PermitUserEnvironment` is global-only** in the macOS OpenSSH inspected here and the Linux manual. My isolated parser negative returned `Directive 'PermitUserEnvironment' is not allowed within a Match block` (exit 255). A configuration-only positive with `PermitUserEnvironment no` globally and the identity/forced-command/forwarding restrictions inside Match succeeded.

Clarify this in the eventual deployment recipe; it is not an unsupported authentication mechanism or a blocker for this conceptual design. The design already requires effective-configuration inspection and refusal on an unproved host. Neither a drop-in nor a successful `sshd -T` proves that earlier includes/Match blocks, alternate key sources, PAM, account login or terminal policy satisfy it. Do not enable a host by merely copying my scratch parser input.

## Correctness review

### The two historical P1s are resolved prospectively, not waived

The old transferred-FD promise is gone. Q26 deliberately bounds trusted FD delegation outside the restricted-agent threat model, correctly stating that a still-enrolled, same-generation transferred operator stream **would authorize its holder**. The replacement prevention topology names one pinned client, shell exec before connect, no fork/exec/helpers/SCM_RIGHTS after connect, and private service ownership. CLOEXEC is defense in depth, not fork/dup/transfer prevention. Actual debugger, descriptor, child-process and IPC routes must be proved closed on both hosts; an accidental/helper route cannot be relabelled deliberate delegation.

The second old P1 supplied hostile schema-valid data to an unspecified root trigger. The new design selects an actual upstream authenticator: an administrator-enrolled operator SSH key, held only by a separately trusted operator workstation/session, authenticating to a dedicated OS account. Authentication selects the fixed client, rather than an agent-accessible queue/launcher selecting operator authority. Root owns account configuration, key list, shell/client and initial UID/principal enrollment. This is a concrete boundary absent from the old topology. The client has no stdin/file/queue/helper fallback; a developer's direct execution remains under the developer UID. A developer without the key/session cannot make sshd create the operator session merely by choosing a remote command, subsystem or valid body.

This conclusion depends on the **stated restricted-agent model**, not a claim that SSH detects human fingers. An agent-held operator key or agent-writable SSH client input invalidates the installation, as lines 31–33 explicitly say. A compromised trusted operator workstation or intentional delegation is outside that model; accidental access to its key, SSH control socket, terminal or helper input is not excused.

### OpenSSH and platform feasibility independently checked

Read local macOS OpenSSH 10.3p1 `sshd_config(5)`, `sshd(8)`, `sh(1)` and relevant `bash(1)` startup semantics, and retrieved the Linux manuals at:

- https://man7.org/linux/man-pages/man5/sshd_config.5.html
- https://man7.org/linux/man-pages/man8/sshd.8.html

They support `Match User`, `ForceCommand`, absolute `AuthorizedKeysFile`, public-key-only authentication, forwarding restrictions and PTY controls. `ForceCommand` replaces **shell, command and subsystem** execution and invokes the account shell with `-c`; it does not itself prohibit forwarding. The original command remains an environment value and must never be interpreted. `DisableForwarding yes`, `PermitTunnel no`, `PermitUserRC no`, `PermitTTY yes`, disabled password/keyboard-interactive/hostbased methods, `AuthenticationMethods publickey`, and eliminating alternate authorized-key commands/CA trust are a feasible standard configuration shape. Key restrictions must not accidentally set `no-pty` and make the positive impossible.

Important qualifications:

- `PermitTTY yes` permits allocation; it does not require a terminal. The client must refuse non-PTY/no-controlling-terminal requests, including SFTP/no-PTY channels.
- `ForceCommand`/`PermitUserRC` do not prove an empty startup path. `/etc/ssh/sshrc`, PAM/environment and shell startup behavior require inspection. Noninteractive bash can read `BASH_ENV`; remote-shell startup can read `.bashrc`. Bash invoked as noninteractive `sh` has different behavior. On this macOS, `sh(1)` documents selection through `/private/var/select/sh`; do not assume a pathname pins a universal shell implementation. The design explicitly requires verification of no startup hook, not faith in `-c`.
- `TERM` is accepted for PTYs even without general AcceptEnv. Installed code must use a bounded trusted terminal/display setup and a closed environment, not caller-selected terminfo/helper behavior. Full canonical display must preserve visible meaning, including escaping terminal controls, and confirmation cannot be satisfied by a hidden/prebuffered helper token. These are implementation obligations of the specified complete-display/no-external-confirmation contract.
- ForceCommand cannot restrict `su`, console/GUI login, another sshd, launchd/systemd jobs or debugger rights. The proposal separately forbids alternate UID-switch/login paths and demands their host inspection. No such inspection was claimed here.

A local **configuration-only** `sshd -T -f <scratch> -h <disposable scratch host key> -C user=...,host=localhost,addr=127.0.0.1` succeeded with the above shape. No listener was opened, account created, host config changed or host service started. The temporary key was deleted. An initial parse without a readable host key exited 1 (`no hostkeys available`); this was fixture setup, not evidence against ForceCommand. Linux evidence is manual/source semantics only, not an executed Linux daemon fixture.

An owned scratch PTY probe further confirmed the limitation: a child opened `/dev/tty` with O_NOFOLLOW, passed `tcgetpgrp == getpgrp`, and read bytes written programmatically through the PTY master. Thus using `/dev/tty` rather than fd 0 **does not stop SSH-client-side piping**; authenticated channel/key custody is essential. This single-UID probe is expressly not distinct-UID host isolation evidence. It supports, rather than contradicts, the new explicit limitation.

### Exact input, intent, retry and bootstrap

Lines 19, 21 and 31 specify bounded closed-schema canonical contract/spec data, duplicate-key and UTF-8 checks, project/operation/request ID/target/expected revisions, installed service identity and peer-bound intent. The client constructs once, displays the entire canonical body and revisions, requires explicit operator confirmation and freezes the bytes before service connect/retry. There is no request reconstruction from mutable lane state or agent path. Revision races refuse through Core's own enrollment/permission/policy/spec/absence read-set CAS; the client is not the only guard.

On lost reply, current authorization is checked before exposing historical results. Full retries match the original request including old expected revisions, without rerunning completed mutation CAS; result-by-ID verifies the stored intent/result association. After client exit, a fresh login must re-enter/confirm the original request or use that authorized result read. It must not silently substitute new session metadata into old canonical intent: preserve original provenance in stored intent and record the new authenticated transport session separately. The stated session-independent peer authority and result-read path make restart feasible; fresh sessions are not permission to change old bytes. Changed body/project/revisions, sibling/revoked reader, fresh ID/same target, missing history and corrupt reopen remain refusal/hold cases.

Initial operator key enrollment, UID/principal mapping and service installation belong to administrator/root-owned bootstrap, not socket self-enrollment or a requested root launch. Fixed release/store/endpoint identity and immutable history must be validated before readiness. The packet's signed-service-release requirement remains an implementation/provisioning obligation: root ownership or this parser check is **not** proof of a verified release signature. No installed signing, bootstrap or recovery evidence exists in this design-only candidate.

### Actual manual lane and protected boundary

Independently inspected Gateway protected/atomic APIs and handlers, startup capability assignment, ManualLane.Server context/open, Backend.admit/allow_scope, Replay.root/submit, CLI context, CLI.RPC, bin/foundry, bin/foundry-lane, Application startup and rel/vm.args. They confirm the design's diagnosis: capability equality authenticates an internal call; actor/principal data remain caller-supplied; Server.context exposes the instance capability to BEAM callers; the wrapper still uses general release RPC. The same-UID manual lane cannot supply protected operator provenance.

Keeping a separate installed no-eval service and private store, retaining the existing internal Gateway capability, and exposing only closed typed admission are appropriate. A new bearer token or actor literal would not repair the existing boundary. Mode guards, authenticated admission history and packet/seal provenance must be enforced inside Core and on every productive alternate route, not just in CLI. No role-specific Core formatter, new workflow reducer, controller-selected callback or protected import of legacy manual admission is authorized.

### Product scope: not an indefinitely unattended new-ticket factory

Q24 removes a human verdict/promotion click for **already admitted eligible work**. It does not authorize arbitrary new operator spec/contract bodies. This candidate states the distinction explicitly at line 27 and Q27; that is not a security defect to solve by giving an ordinary agent the operator key.

Nevertheless the reviewed provenance design still requires an immutable operator-admitted ticket/attempt spec before producer issue. With only this ingress, each such new spec/body needs human authorization; moving accepted bases or new attempts may also require renewed admission. Unattended processing can consume a preadmitted finite queue, but an indefinitely self-admitting factory is **not delivered**. Future autonomous new-ticket admission needs its own reviewed finite standing-policy rule and input provenance. Report this limitation in product claims and operator-hour evaluation; “exceptional” wording cannot erase the per-new-spec dependency.

Read AGENTS/index/brief, boundary rules and R3, live Q24/Q25/Q27 plan and handoff, custody, autonomous review, packet provenance, atomic binding and reconciliation designs. Q25's acyclic Foundation → Candidate → Review Broker → Custody Closure → Acceptance sequence survives. No historical verdict, frozen contract, terminal non-start proof or nonempty-check schema is silently amended. The duplicate ingress index row from the previous P3 is removed.

## Separate Ponytail Review — complexity

The need is real; the old manual capability cannot authenticate operator instructions. OpenSSH is a justified existing standard-platform authenticator rather than a new password/token protocol. Reuse it, platform UID/service ownership and existing Core transaction/history/CAS. Keep one fixed client and closed request path; no queue, plugin framework, second authority store or speculative autonomous admission API. Security validation and actual-host positive/refusal/red evidence are not optional simplifications. No dependency or runtime code is added here.

## Checks and residual risk

- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS **469/800 words**.
- `git diff --check 50aa40bc53429c4b0d2daddc715f379d7e2d8b4b..9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9`: passed.
- Python/git identity/scope/history assertions: passed; exact clean detached candidate, base ancestry, three commits, exact four-path scope, historical tree equivalence, both notes digests matched.
- macOS sshd configuration-only positive and unsupported-Match negative: expected outcomes; no daemon/listener/install. Owned PTY-master counterexample: observed expected limitation, not protected-host acceptance.
- Main checked clean at exact base. Pre-verdict status: lane ready, ticket reviewing, exact candidate and this issued reviewer execution.
- No source tests, full gate, FR-08A rebind, sudo, host installation, alternate-account login, real restricted-UID macOS/Linux attack, signed-release verification, protected service positive/restart, provider test, CI, merge or push.
- Residual risks: implementation and real two-host input/PTY/FD/debug/bootstrap/revocation/restart/red proof remain entirely outstanding. Model judgment/prompt injection and operator mistakes remain possible. Trusted workstation/key compromise and deliberate FD/key delegation remain outside this bounded model. New-ticket autonomous admission is unsupported. The present manual lane is only a supervised record.

## Immutable lane recording

The runtime-authoritative output-path override makes **this file** the external notes artifact instead of the task's alternate notes filename. I will personally submit `approved` from main with the exact packet principal/candidate using this path, then verify the receipt, committed status/event and archived SHA-256. This file will not be rewritten after submission; the final response supplies receipt confirmation. Notes alone are not a lane verdict.

```acceptance-report
{
  "criteriaSatisfied": [{"id":"criterion-1","status":"satisfied","evidence":"Full-range independent design review above; no blocking design finding, one P3 deployment note, explicit residual risks and actual check outcomes."}],
  "changedFiles": [],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {"command":"elixir bin/check_docs.exs","result":"passed","summary":"0 broken links; AGENTS 469/800 words"},
    {"command":"git diff --check 50aa40bc53429c4b0d2daddc715f379d7e2d8b4b..9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9","result":"passed","summary":"No whitespace errors"},
    {"command":"Python/git candidate, scope, history and archived-notes assertions","result":"passed","summary":"Clean detached candidate, exact four-doc scope, three commits, historical tree and notes digest equivalence"},
    {"command":"sshd -T scratch configuration positive and invalid-Match negative; owned PTY probe","result":"passed","summary":"Supported configuration parses; global-only directive rejected inside Match; foreground PTY still accepts master-supplied input"}
  ],
  "validationOutput": ["APPROVED, design only, exact candidate 9fc17803ec86e792a4bafdc73dcd44d7bfa01ed9", "Lane submission and archive confirmation follow this immutable notes snapshot"],
  "residualRisks": ["No installed macOS/Linux distinct-UID, input/FD, bootstrap, signed-release or restart proof", "Trusted workstation/key compromise and deliberate delegation are outside the bounded threat model", "Autonomous new-ticket/spec admission remains unsupported; preadmitted finite work only"],
  "noStagedFiles": true,
  "diffSummary": "Documentation-only three-commit range, four admitted paths, +61/-2; reviewer edited no candidate files",
  "reviewFindings": ["No blockers", "P3: ingress design line 29 — PermitUserEnvironment is global-only, not Match-legal; retain effective-config and host gates"],
  "manualNotes": "Fresh independent review; both historical P1 corrections checked, platform behavior challenged, Ponytail applied separately. No authority to enable protected service. Final response will confirm personal lane recording."
}
```
