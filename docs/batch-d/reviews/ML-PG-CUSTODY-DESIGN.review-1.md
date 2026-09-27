# ML-PG-CUSTODY-DESIGN independent critical review

- Candidate: `2da53b8d04bf821b5eb9cf5eff083b8855cf0595`
- Base: `717571148a0824db0de7dff1d5be2f020458faaa`
- Reviewer: `agent:codex-gpt-6-astra/review-ML-PG-CUSTODY-DESIGN`
- Verdict: **correction**
- Scope: the exact three-file documentation delta, current manual-lane code and launcher, host identity/ownership, and the cited platform mechanisms. Detached candidate worktree remained clean. No implementation or installed boundary is approved.

The service UID, private state/bare repository, authenticated Unix socket and removal of Erlang distribution are a viable foundation. The design honestly records that none is installed. Three boundary decisions still need correction before implementation.

## Ranked findings

### 1. P1 — Specify an external reviewer-agent path that does not lend its authority to candidate tools

**Location:** `docs/design/PORTABLE-CUSTODY.md:29-31`, acceptance rows at 41-44.

The reviewer is given a UID with verdict authority, but line 31 says running unrestricted agent tools as that UID compromises the role and requires a human or separately controlled review client to submit instead. That is a safe refusal, but leaves the requested independent agent submitting its own verdict undefined. The positive acceptance row exercises only a trusted session; the hostile-test row exercises only a developer UID.

**Counterexample:** a reviewer agent runs `mix test` on the frozen candidate under its reviewer account. Candidate-controlled test/setup code opens `authority.sock` and submits an approval for the reviewer's own outstanding assignment. The peer UID, role, project, candidate and assignment all match. No token theft or direct store write is necessary. A fresh request ID is sufficient. Calling this an independent trusted session does not separate those processes. The same problem applies to project startup hooks, extensions and tooling loaded by a desktop reviewer client.

**Required correction:** state the concrete supported reviewer topology and how candidate execution is forced into an identity without reviewer authority. Name which process owns review submission and which tool/worker process can execute project code; define the transfer of source, notes and results. A client-specific adapter may enforce this outside Foundry, but it must be specified and verified before that client is supported. Add a positive external-reviewer-agent submission control and a hostile candidate executed through its real tool route that cannot submit a verdict. Explicitly reject the current shared-admin-UID desktop setup. If the intended milestone is human-only review submission instead, obtain and record that workflow change rather than treating it as the promised agent workflow. This asks for custody of review authority, not FR-15aB's full provider/network isolation.

### 2. P1 — Define client-side file handling before reusing the privileged CLI

**Location:** `docs/design/PORTABLE-CUSTODY.md:33`; current `lib/foundry/manual_lane/cli.ex` functions `command("packet", ...)`, `write_packet/2`, `command("review", ...)`, `read_notes/1`.

The design forbids candidate execution through `--checkout`, but says the current CLI/backend can be reused after unauthenticated entry points are removed. Authentication alone does not make those CLI handlers safe under `foundry-svc`: packet `--out` invokes `File.write` inside the daemon, and review `--notes` invokes `File.read` there. The new wire vocabulary does not explicitly remove those path operations.

**Counterexample if the present CLI handlers are retained:** an authenticated developer retrieving its legitimate packet sets `--out` to the service-owned policy, authority database or accepted-ref path. The service itself truncates/writes the protected file. All external OS write checks still pass. A review notes path likewise makes the service read files the caller cannot read. The current CLI's privileged file I/O is observable in source; this is a required migration constraint, not a claim that the unimplemented socket already permits these calls.

**Required correction:** make `--out` and `--notes` client-local conveniences. Return packet bytes; accept bounded notes bytes, not a server filesystem path. Enumerate or explicitly prohibit caller-selected service read/write paths in the socket vocabulary, and route only authenticated semantic backend operations. Add a valid enrolled-caller control attempting the old `--out`/`--notes` shapes and a symlink target; protected files must remain unchanged. Keep candidate import's larger implementation in CANDIDATE.

### 3. P2 — Make UID retirement and revocation enforceable across persistent sessions and role reuse

**Location:** `docs/design/PORTABLE-CUSTODY.md:15,19,31,33,43`.

The account requirement covers concurrently active principals, and retirement only says a UID cannot be silently recycled while processes or sockets remain. It does not define whether role/principal reassignment is permanently forbidden, how a revoked open connection loses authority, or how durable mappings and outstanding assignments recover after restart. These are security semantics for the chosen credential, not provisioning detail that can be inferred from socket permissions.

**Counterexamples:** (a) a server caches the principal at connection acceptance; after revocation the connection still names an issued claim and submits. The text requires assignment checks but does not require revocation to invalidate that assignment/session. (b) after all old processes and sockets exit, an account formerly used by a developer is remapped to a new reviewer principal; old user-owned startup files or executables persist and run in the next session. The two active-principal check passes, and a new label can also evade historical producer inequality.

**Required correction:** choose the minimum enforceable policy. For this first host, permanently bind each enrolled UID to its principal/role and refuse reuse; or specify identity generation, retirement, cleanup and historical producer binding. Persist revocation and check current enrollment on every operation, including existing connections; state what happens to outstanding claims and cached results. Add revoke-while-connected, revoke/restart/reconnect, and attempted developer-to-reviewer reassignment controls. Group membership changes alone do not revoke an already connected stream.

## Platform and source checks

- Full candidate diff: only `docs/README.md`, `docs/REPAIR-PLAN.md`, `docs/design/PORTABLE-CUSTODY.md`; 51 insertions, 2 deletions. The seven-row milestone count and reviewed-design predecessor are consistent. Full FR obligations remain open.
- Read the portable contract, current queue and standing brief, Server/Backend/CLI paths, GitEvidence, application startup, release configuration, lane scripts, CI workflow and relevant runbook. `Server.context/0` exposes the capability within the BEAM; the present CLI uses caller labels and release RPC. Replacing transport and startup is necessary.
- `id`, account listing, process identity and file metadata confirm UID 501/admin, no Foundry role account, the current lane under UID 501, and user-owned database/policy files at 0644. Those observations support the document's lack-of-isolation claim. No state or credential contents were used in the review.
- Harmless local macOS AF_UNIX/getpeereid probe used an ephemeral socket and two forked client processes, with no Foundry access. Both the simulated review client and candidate-tool child returned peer `(501, 20)`. Two observations passed: peer credentials distinguish OS identities, not purposes or sibling processes. No distinct-UID isolation or protected-route success is claimed.
- `elixir bin/check_docs.exs`: **0 broken links**, AGENTS 481/800 words. `git diff --check`: exit 0. Candidate worktree clean before and after review. No full gate, provider session, restricted-account fixture, Linux test, host provisioning or FR-08A rebind ran.

[Apple getpeereid](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getpeereid.3.html) confirms that peer credentials reflect connection/listen time, supporting authentication but not ongoing revocation. [Linux unix(7)](https://man7.org/linux/man-pages/man7/unix.7.html) gives the same timing for SO_PEERCRED and documents pathname permissions; socket mode behavior is not universally portable. The proposed protected directory and peer check remain necessary.

[Apple's daemon guide](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html) supports a system LaunchDaemon and configured UserName. [systemd.exec](https://man7.org/linux/man-pages/man5/systemd.exec.5.html) supports User and managed directories; explicit directory modes are necessary because their defaults are 0755. [Mix release](https://mix.hexdocs.pm/Mix.Tasks.Release.html) supports RELEASE_DISTRIBUTION=none, so removing distribution is feasible; the present launcher's RPC/pid/stop path must be replaced by the service manager and socket status. Fixed startup also needs a trusted HOME/PATH/configuration and no inherited release overrides. Those changes must be inspected and tested on the installed host.

The current GitHub workflow contains no isolated role fixture. [GitHub runner documentation](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) supports privileged provisioning on hosted Linux, but does not make ordinary same-UID tests isolation evidence. Future fixtures must actually run hostile code as the restricted user without inherited privileged sockets/file descriptors.

## Separate Ponytail Review

Lean already. No abstractions, dependencies or implementation machinery were added. The service account, platform peer credentials and existing Gateway are reasonable reuse choices. The findings require concrete authority boundaries and acceptance controls; they do not justify building a general sandbox or a second workflow store.

## Disposition

Correct the three decisions and obtain renewed review of the exact document candidate before ML-PG-CUSTODY code. Platform documentation supports the foundation; only future real restricted-caller and reviewer-tool controls can establish the boundary. This review does not ask the design ticket to provision accounts or claim unrun isolation tests passed.
