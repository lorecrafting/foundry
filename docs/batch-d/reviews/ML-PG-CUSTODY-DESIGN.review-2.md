# ML-PG-CUSTODY-DESIGN independent correction re-review

- Candidate: `bea24a1f47a794e01ece316895dfe7c5ba28b242`
- Base: `717571148a0824db0de7dff1d5be2f020458faaa`
- Prior candidate: `2da53b8d04bf821b5eb9cf5eff083b8855cf0595`
- Reviewer: `agent:codex-gpt-6-astra/review-ML-PG-CUSTODY-DESIGN-2`
- Verdict: **correction**

The three original findings are resolved at design level. One new replay-ordering ambiguity must be corrected before implementation. This review approves neither an installed boundary nor agent reviewer self-submission.

## Ranked finding

### 1. P2 — Separate retry-result authorization from mutation revision preconditions

**Location:** `docs/design/PORTABLE-CUSTODY.md:33`, retry control at line 45; compare `docs/design/PORTABLE-GOVERNANCE-CONTRACT.md:13` and its promotion semantics.

The correction says the service checks assignment and **current protected revisions before ... cached-result return**, but the next sentences promise an identical retry by the same currently enrolled actor returns the recorded result. A completed mutation can itself change those revisions or consume its claim. Applying its original mutation preconditions before returning its recorded result contradicts the retry promise.

**Concrete counterexample:** an authorized operator submits promotion request R, expected accepted ref A, target B. The service commits success, advances the protected ref to B, and the response is lost. After restart, the still-authorized operator repeats exactly R. Rechecking its expected accepted-ref revision against current B refuses the request, although the durable record already establishes that R succeeded. A successfully consumed review/submit claim has the same ordering hazard if “checks assignment” includes requiring an outstanding claim. This is a design contradiction/ambiguity, not a claim that an unimplemented endpoint already behaves this way.

**Required correction:** state the order explicitly: authenticate the peer and check current enrollment/revocation and permission to read that recorded outcome; match request ID, actor, project and complete content against the durable record; return the original outcome without reapplying the completed mutation's old revision or unconsumed-claim preconditions. Apply mutation revision and claim checks only when executing a new request. Preserve the refusal of revoked actors and changed-content/sibling retries. Add one acceptance control where a committed request changes its own expected revision or consumes its claim, loses its reply, then returns the original outcome on an identical retry after restart. Current access authorization must remain distinct from permission to execute the mutation again.

## Disposition of prior findings

1. **Reviewer/candidate same UID — resolved.** Lines 15, 29 and 31 now explicitly reserve reviewer authority for a separate trusted human and review-only client. The agent drafts untrusted notes under an identity without reviewer authority. The client cannot execute candidate tests, hooks, shell tools or extensions, and the current shared-admin desktop setup is explicitly unsupported. Line 44 pairs the actual hostile agent tool route with a legitimate human verdict bound to the exact candidate and issued assignment. The repair plan records the narrowed workflow, acceptance owner and human review cost. The portable contract already permits a separate authenticated reviewer and does not require that reviewer to be an agent. A review-only client displaying source/check facts and accepting a human decision can implement this narrowing; future host acceptance still must establish the real process identities and tool routes.
2. **Privileged path operations — resolved.** Line 33 makes packet output and notes input client-local, sends packet/notes bytes through the socket, rejects server path fields and legacy flag shapes, and requires semantic backend reuse without privileged CLI file I/O. Line 43 includes an enrolled caller, protected-file targets and a symlink. The current `CLI.write_packet/2` still writes a caller path at `lib/foundry/manual_lane/cli.ex:416`, and `read_notes/1` reads one at line 505; the new design now explicitly prevents carrying those handlers into the service unchanged. No protected endpoint implementation is claimed.
3. **UID retirement and revocation — resolved.** Lines 19 and 31 permanently bind UID/principal/role, prohibit retirement reuse, persist revocation, reload it before accepting connections and check it on every operation, including old connections and cached-result reads. Outstanding revoked executions remain pending/unknown for evidenced operator reconciliation and cannot be reassigned. Line 47 covers live revocation, restart retry and attempted developer-to-reviewer reuse. These requirements close the previous cache-at-connect and account-remapping counterexamples. The remaining finding concerns successful authorized retries, not weakening revocation.

## Checks and limits

- Read the second packet and brief, original brief and review, standing agent brief, documentation index, relevant repair-plan sections, approved portable contract, full three-file base-to-candidate diff and original-to-correction diff.
- Confirmed detached HEAD equals the exact candidate and the worktree is clean before and after review. Delta is three documentation files, 60 insertions and 4 deletions; no runtime implementation changed.
- Used Elixir ast-grep to locate the existing CLI `File.write/2` and `File.read/1`, inspected their surrounding handlers, and read the current RPC wrapper. These are source checks of the migration constraint, not tests of a new endpoint.
- `elixir bin/check_docs.exs`: **0 broken links**, AGENTS **481/800 words**.
- `git diff --check 717571148a0824db0de7dff1d5be2f020458faaa..HEAD`: exit **0**.
- No full gate, rebind, provider session, host provisioning, OS account fixture, new socket test or Linux test ran. Prior platform/host evidence is retained as supplied; it was not rerun. All isolation and client-route controls remain future executable acceptance obligations.

## Separate Ponytail Review

Lean already. No abstraction, dependency or implementation machinery to cut. Keep the existing Gateway and platform identity boundary. The required correction only distinguishes authorization to read a recorded result from preconditions to execute a new mutation; it needs no second request store or retry subsystem.
