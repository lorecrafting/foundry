# Arm B workflow checklist

[Foundry](../../README.md) › [Docs](../README.md) › [Strategy](../STRATEGY.md) › Arm B workflow checklist

**Status:** unscored pilot preparation; not three-way results.

Supplement the operator's existing workflow prompt and repository `AGENTS.md`; do not repeat coding conventions. For prospective arm B of the [first pilot](VALIDATION.md#first-pilot-local-workflow-assistant-versus-prompting), paste this checklist into Pi, Codex or Claude Code and fill every bracketed field before work starts:

```text
Work under the existing workflow prompt and repository instructions. This checklist adds pilot evidence requirements; it does not replace them.

Ticket: [exact ticket]
Base: [full commit SHA]
Allowed scope: [exact files or paths]
Acceptance: [explicit, testable criteria]
Branch: [isolated branch name]
Required checks: [exact commands]
PR destination: [repository and target branch]

1. Confirm the named base is HEAD and the working tree is clean before editing. Work only on the isolated branch and within the stated scope and acceptance criteria. Stop and report if they conflict or need widening; do not silently expand scope.
2. Before requesting review, leave a clean candidate at a recorded full commit SHA. Run every required check against that candidate and record each exact command and result. Do not claim unrun checks passed.
3. Have a fresh reviewer using a different model inspect the exact candidate and full change in a separate detached worktree. Give the reviewer the ticket, base, scope, acceptance and check results. Record reviewer model, candidate SHA, findings and verdict; do not self-review as independent review.
4. If corrections are needed, make them on the branch, rerun relevant and required checks, record the new clean candidate SHA, and request rereview of that exact candidate in a separate detached worktree. Repeat until approved; approval of an earlier SHA does not cover later changes.
5. Submit the full reviewed range through a PR. Verify CI for that range and record its result. Complete normal Git integration (for example, merged PR and resulting integration SHA); a lane phase or receipt is not Git integration or proof of acceptance. Do not claim integration until verified.
6. Record total operator time, including setup, prompting, checks, review, corrections and PR work; rework rounds/time; and defects found, escaped or still open. Preserve unknowns as unknown.

This is ordinary, unprotected workflow evidence: do not claim protected identity, acceptance or receipt. Do not call lane packet, submit or review for this preparation. Report observations only; do not present this artifact as scored pilot data or three-way results.
```
