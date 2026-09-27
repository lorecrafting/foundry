# ML-PG-CUSTODY-DESIGN independent third review

- Exact candidate: `609fa227064a8d80d28e406899e64d6285bff815`
- Base: `717571148a0824db0de7dff1d5be2f020458faaa`
- Reviewer: `agent:codex-gpt-6-astra/review-ML-PG-CUSTODY-DESIGN-3`
- Verdict: **approved**
- Scope: the full three-commit, three-document candidate, including both prior corrections. This approves the static first-host design for implementation. It does not establish an installed isolation boundary or approve agent reviewer self-submission.

## Findings and prior-review disposition

No blocking finding remains in this candidate.

The prior P2 retry-ordering finding is resolved in `docs/design/PORTABLE-CUSTODY.md:19` and `:33`. Current enrollment, revocation, role/project access and permission to read the outcome precede recorded-result access. A matching durable request returns its recorded outcome without repeating the old mutation's revision, assignment or unconsumed-claim checks. Only a new request reaches those mutation preconditions. The complete canonical content includes expected revisions. The new acceptance row at line 46 explicitly covers a request whose own success makes those original preconditions stale.

I traced these cases against the written ordering; these are design counterexample checks, not executable endpoint tests:

| Case | Required path and conclusion |
|---|---|
| Operator request R expects accepted A, commits promotion to B, loses its reply, then restarts and retries R unchanged | Current authorized actor passes read access; actor/project/content match the durable record; original result returns. The stale expected A is compared with recorded request content, not current B. No second promotion is issued. |
| Submission/review consumes claim C, loses reply, then retries exactly after restart | Its authorized owner reads the matching stored result without requiring C to remain unconsumed. No second event or claim consumption occurs. |
| Same ID and actor with altered body or expected revision | Complete canonical content mismatch refuses before new mutation execution. |
| Sibling enrolled UID replays the original request | Authenticated actor mismatch refuses even when the sibling can connect or see similar packet material. A body principal cannot override peer identity. |
| Revoked UID retries an old request, including on an already open connection or after restart | Current enrollment/revocation refuses before the old result is returned. Restart loads that state before requests. |
| Fresh request ID reuses consumed claim/review/promotion | It follows the new-request path and cannot bypass current claim and revision preconditions. |
| Same enrolled actor loses project/outcome read permission | Current read authorization remains required; possession of an old ID is insufficient. |

The earlier three findings remain resolved:

1. **Reviewer tools:** lines 15, 29 and 31 require a trusted human reviewer and a review-only client under a distinct UID. Candidate-executing agent tools lack reviewer authority. The current shared-admin desktop is expressly unsupported. Line 44 tests the real hostile tool route and the separate legitimate human verdict. The plan records this narrower workflow and its human review cost at lines 128-131 and in the CUSTODY, ACCEPTANCE and EVALUATION rows. The portable contract permits a separate authenticated reviewer; this topology does not weaken its exact-candidate or producer-inequality requirements.
2. **Privileged file paths:** line 33 keeps packet output and notes input in the caller process, exposes bytes through the socket and rejects server path fields and old CLI flag shapes. Line 43 includes enrolled callers and a protected-file symlink. The existing `CLI.write_packet/2` and `read_notes/1` still perform file I/O; the design explicitly prohibits retaining that behavior in the privileged endpoint. Candidate import remains a separate CANDIDATE obligation.
3. **UID reuse/revocation:** lines 19 and 31 permanently bind the enrolled UID/principal/role, prohibit reassignment and require durable revocation checked on every operation. Outstanding revoked executions require evidenced operator reconciliation. Line 47 covers open connections, restarted cached requests and developer-to-reviewer reuse. The retry fix did not remove any of these current-access checks.

## Full-candidate consistency and sources

The first-host topology protects service state, policy and the local bare accepted repository under a separate service UID and private paths. The candidate and check worker remain outside it. The socket vocabulary is closed, peers and endpoint are authenticated, and general release RPC/distribution is removed from the protected service. Unsupported provisioning, peer-credential, path, socket and recovery conditions disable mutations. CANDIDATE retains safe object import; ACCEPTANCE retains promotion claims, exclusion, CAS and reconciliation. This does not mark full FR-15aB, provider/network/tool isolation, autonomous execution or deployment complete.

The repair plan adds the reviewed design predecessor, preserves the remaining FR obligations and correctly counts seven milestone packets. The documentation index links the proposed design. No out-of-scope source or tests changed.

I checked the cited platform documentation independently. [Apple getpeereid](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getpeereid.3.html) and [Linux unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html) support peer credential lookup; credentials reflect connection/listen time, so the separate current revocation check remains necessary. Linux also warns that socket-file permission behavior is not universally portable; the design requires real host checks and protected directory ownership.

[Apple's daemon guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) supports system daemon configuration, UserName and KeepAlive. [systemd.exec](https://man7.org/linux/man-pages/man5/systemd.exec.5.html) supports the service identity and managed runtime/state directories; the specified private modes must be explicit because managed directory modes otherwise default to 0755. [GitHub's runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) confirms hosted Linux permits provisioning with passwordless sudo. The actual checked-in workflow only runs the ordinary gate and has no isolated role fixture. These sources establish available mechanisms, not deployed conformance.

## Checks and limits

- Read the third packet and brief, both earlier review reports, standing agent brief, documentation index/top-level README, relevant repair-plan sections, approved portable contract and complete candidate documents/diffs.
- Confirmed clean detached HEAD at the exact candidate before and after review. The three commits change only `docs/README.md`, `docs/REPAIR-PLAN.md` and `docs/design/PORTABLE-CUSTODY.md`: 61 insertions, 4 deletions.
- Inspected current CLI file-I/O handlers using Elixir ast-grep plus bounded source reads, `Server.context/0` and its handler, the current release-RPC wrapper and CI workflow. An initial parenthesized `def context()` pattern had no match; direct inspection confirmed the actual one-line `def context, do: ...` and capability-returning handler. No implementation test is inferred from these source checks.
- `elixir bin/check_docs.exs`: **0 broken links**, AGENTS **481/800 words**, exit **0**.
- `git diff --check 717571148a0824db0de7dff1d5be2f020458faaa..HEAD`: exit **0**.
- No full gate, FR-08A rebind, runtime code change, provider session, account provisioning, restricted-UID test, Linux fixture or protected socket/restart test ran. Earlier reported host observations were read as supplied evidence, not rerun. The seven traces above are static reasoning over an unimplemented protocol.

The next implementation must supply the document's actual isolated-caller and hostile-tool acceptance, including the lost-reply retry after its own successful revision/claim change. This approval is only for the SHA above.

## Separate Ponytail Review

Lean already. Ship.
