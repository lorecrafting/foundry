# Portable governance contract — first governed-acceptance milestone

[Foundry](../../README.md) › [Docs](../README.md) › Portable governance contract

**Status:** proposed design for independent review, 2026-09-26. This changes neither the running manual lane nor the full [workflow contract](../WORKFLOW-CONTRACT.md). The [portable milestone queue](../REPAIR-PLAN.md#portable-milestone-tickets-in-dependency-order) owns implementation and acceptance. Version **1** below is the proposed semantic contract, shared by CLI and MCP; it is not a claim that either transport implements it.

## Present boundary

Today `ManualLane.CLI` admits a resolved Git base and accepts an explicit principal string, `Backend` issues a claimed work packet and records submit/review receipts, `WorkPacket` carries stable ticket/attempt/execution/effect/claim IDs, and `Replay` rebuilds status from committed events (`lib/foundry/manual_lane/{cli,backend,replay}.ex`, `lib/foundry/work_packet.ex`). Core enforces recorded reviewer-principal inequality. The CLI checks a clean checkout, exact HEAD and base ancestry through `lib/foundry/git_evidence.ex`; that check is only a mutable-checkout observation at submission time. The policy seeds an empty check set (`lib/foundry/manual_lane/server.ex`), so no trusted check runs. `lane integrated` runs `git cherry` against a caller-selected ref and writes no acceptance fact (`lib/foundry/manual_lane/cli.ex`). Principal labels are not authenticated; integration is an operator's Git action. The [runbook](../batch-d/LANE-RUNBOOK.md#7-out-of-scope) records these limits.

## Version 1 facts and requests

Each mutating request carries `contract_version: 1`, a caller-generated `request_id` and the expected revisions of the protected facts it depends on; the service binds its authenticated caller principal. The service stores the request digest, result or refusal, actor and revisions durably. The same ID and identical request returns the original outcome after retry or restart; changed content with the same ID refuses. An ambiguous reply is resolved by reading the request result, never by inventing a second action. Unknown versions and fields that purport to grant authority refuse. Status reads return these facts and their revisions; display phase is a projection, not proof of acceptance.

| Semantic operation | Request and authoritative result |
|---|---|
| Admit | Operator supplies objective, immutable base commit, scoped paths, acceptance criteria and policy revision. Result is `ticket_id`, `spec_revision_id`, admitted base and policy revision. A new spec gets a new revision. |
| Status | Read ticket/attempt/execution IDs, phase, outstanding claims, candidate, check and review IDs, accepted-ref commit and pending promotion effect. It does not change state. |
| Assign/submit | An issued `execution_id`/`claim_id` binds a role and principal. Developer submits a commit ID; Foundry freezes verified Git objects and records `candidate_id`, commit and tree IDs, base/spec/policy revisions and producing execution. Blocked/unknown work remains explicit. |
| Required check | Protected policy selects check IDs. A trusted worker records `check_receipt_id`, exact candidate tree, check definition/command, toolchain and environment digests, exit/result and policy revision. An agent's output or exit claim cannot satisfy a check. |
| Review | A distinct authenticated reviewer receives the frozen candidate and records `review_id`, verdict, notes digest, candidate commit/tree, spec/policy revisions and required check receipt IDs. A changed candidate, base, policy or check set needs new checks and review. |
| Acceptance | Protected predicate records `acceptance_id` only for the same frozen candidate, passing required checks and approved independent review under current admitted revisions and scope. `ready_to_integrate` or a reviewer verdict alone is insufficient. |
| Promote | Authenticated operator asks to promote that acceptance with expected accepted-ref old commit. Foundry issues one durable effect claim, then its protected writer attempts only a fixed old-to-new Git ref compare-and-swap. Result records exact new commit/tree or a visible conflict/pending state. |

IDs identify facts across client restarts; revisions prevent a stale request from borrowing a newer policy, spec, candidate, review or accepted base. A correction creates a new attempt/candidate identity. A repeated submit, check, review or promotion cannot create a second fact/effect. Foundry authorizes by the authenticated principal and assigned role, not by a supplied `principal` field, packet text, client hook, model name or session ID. CUSTODY must implement caller authentication, credential replay resistance, operator/developer/reviewer separation and protection of store, policy and accepted Git evidence from agent-controlled processes. An independently authenticated reviewer must differ from every producer principal for that attempt; merely spelling two labels differently is insufficient.

CANDIDATE must import immutable commit/tree objects into protected custody, verify admitted-base ancestry and the full changed path set, and prevent candidate code, Git hooks or project check definitions from certifying themselves. Candidate code and its check worker run outside protected authority; the trusted check receipt binds the exact tree and inputs above. ACCEPTANCE must recheck that evidence and the exact review at acceptance and promotion, including the current accepted base. No unreviewed merge or patch-equivalent cherry-pick is the accepted candidate.

The **sole authoritative accepted source ref is `refs/foundry/accepted` in the protected project repository**. Only Foundry's protected promotion writer may create or update it; agents, check workers, client adapters and ordinary Git push credentials cannot. Its initial value must be installed by an authenticated operator from a verified commit before the first promotion. `main`, a remote branch, a PR merge or a ref observed after an agent push can be reported as external integration, but none is Foundry acceptance. Promotion proves the protected ref points to the reviewed commit and tree, not that any deployment occurred.

Before the ref operation, Foundry durably issues a promotion claim naming accepted old commit, exact new commit/tree and acceptance ID. The writer uses fixed `git update-ref <ref> <new> <old>` semantics, never a client-supplied command or ref. On restart, reconciliation reads the protected ref and verified objects: exact new commit/tree settles success, exact old commit permits a retry only after the previous issuer/channel is proved unable to act, and any third value is a conflict requiring operator investigation. A missing or corrupt object is not success. The durable effect remains visibly pending or unknown until reconciled; a crash after the Git CAS cannot manufacture a second promotion or silently mark failure. A moved accepted base requires a new candidate with checks and independent review.

## Two client mappings

| Lifecycle | Codex CLI/skill client | Claude Code MCP client | Foundry fact |
|---|---|---|---|
| Start | Operator admits through CLI; Codex reads packet | Operator admits through MCP; Claude Code reads packet | Same ticket/spec/base/policy revisions |
| Work | Codex runs its own session and submits commit | Claude Code runs its own session and submits commit | Same assigned principal, frozen candidate commit/tree |
| Verify/review | Client polls status and hands review to a separate authenticated reviewer | Client polls MCP status and hands review to a separate authenticated reviewer | Same trusted checks and exact independent review |
| Finish | Operator requests promotion through CLI | Operator requests promotion through MCP | Same acceptance ID, protected ref CAS and reconciliation |

Client session IDs, prompts, hooks, tool-call formats and completion signals stay outside protected facts. Both transports must call the same semantic operations; neither can supply a protected verdict by asserting that its native agent finished.

## Limit and open decision

This milestone governs Foundry's own state and accepted source. It does **not** enforce model spend, launch agents, recover their sessions, isolate their network/tools, or build, deploy or activate accepted code. External clients own those activities; unavailable integration never falls back to self-reported identity or checks. The broader FR-06 autonomous lifecycle remains separate.

**Operator choice before CUSTODY/ACCEPTANCE:** where should the protected project repository and initial accepted commit be provisioned? Option A is a dedicated local bare repository owned by the protected service, seeded once from a verified operator-selected commit; it gives a clear exclusive writer but needs explicit backup and a separate sync to public `main`. Option B is a protected ref namespace in an existing Git host with server-enforced write credentials; it reduces local custody but depends on host-side atomic old-to-new updates and credential isolation. Both preserve the same ref name and semantics. No ordinary checkout ref or branch protection setting alone satisfies exclusive write custody.
