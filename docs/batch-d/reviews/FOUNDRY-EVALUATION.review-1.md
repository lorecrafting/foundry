# Q20 Foundry-internal evaluation review

**Verdict: correction required — one bounded P2 measurement clarification.** The internal-pilot decision, removal of LokaCore from the first milestone, protected acceptance boundary and C2 ordering are consistent. No implementation or authority expansion is needed to resolve this finding.

Reviewed exact candidate **`e9408c92e8fe2a3bfce6b0be74d44630857a67c9`**, parent `b3e2d6d`, in clean detached `/private/tmp/foundry-evaluation-review`. Scope: the five changed documentation files named in the brief. This is an independent documentation review, not a lane verdict or runtime certification.

## Ranked notes

### 1. P2 — Define the primary outcome's eligibility and reconcile the two scorecards

**Location:** `docs/strategy/VALIDATION.md:59–72`, compared with `:76–89`; `docs/REPAIR-PLAN.md:155` adopts the new adjudicated outcome.

The internal pilot's primary measure is now “changes adjudicated acceptable ... per total operator hour,” while the general scorecard immediately below still requires “accepted changes that remain acceptable.” These are different populations. A good candidate falsely blocked by its assigned workflow, or a shadow candidate never eligible for acceptance, can satisfy the first wording but cannot satisfy the second. Merely inspecting its tree and CI does not show the native or Foundry workflow actually accepted it. The shadow warning correctly prohibits prevention claims, but does not specify whether these candidates count in the primary usefulness numerator. Thus two operators following this document can score the same pilot differently, particularly when governance falsely blocks legitimate delivery.

**Smallest correction:** state which observed workflow state qualifies for the primary numerator, and make the general scorecard explicitly defer to this pilot's metric or use the same definition. Recommended wording: “The primary outcome counts candidates actually accepted under their assigned workflow's declared rules and independently adjudicated acceptable through follow-up. Report never-eligible shadow candidates and acceptable-but-blocked candidates separately as quality/overhead evidence.” Ordinary baseline acceptance remains distinct from Foundry accepted-ref promotion and from later live integration. Alternatively retain candidate-quality throughput as the primary measure, but explicitly call it that, exclude claims of accepted delivery from it, and report actual acceptance throughput alongside it. No new evaluation machinery is required.

### 2. P3 — Record the governed service version while evaluating Foundry's own development

**Location:** `docs/strategy/VALIDATION.md:48–57`; nonblocking protocol hardening.

The preregistration already pins policy/check revision, models and ordinary protections. Internal development can also change the deployed Foundry service during a comparison. Record its exact running revision per trial and avoid comparing matched trials across a service upgrade without reporting that change. A single sentence suffices; a permanent release freeze is unnecessary. This guards attribution as the product under evaluation changes.

## What holds

- Q20 explicitly supersedes only Q19's pilot repository. The plan and handoff preserve C2 first, the portable milestone's dependency chain, and deferred full-autonomy obligations.
- Prospective ticket matching, task-class comparisons, practical model/check/review parity, independent adjudication, sample sizes, uncertainty and missing-follow-up reporting can support an internal comparison. They do not by themselves prove a randomized causal effect; interpretation must stay within the recorded matching and allocation limits.
- The baseline retains its ordinary permissions, PR/CI protections and review standard. Its results reach the live repository only through normal reviewed integration, recorded separately. Neither arm's agent receives the other arm's authority or accepted ref.
- The unchanged contract/custody/acceptance rows still require protected exact-candidate promotion, independent authenticated principals, old-to-new ref CAS and recovery. Ordinary PR/CI results and external ref observations do not become Foundry acceptance.
- Prevention requires the native workflow actually to accept the same unsafe attempt under its declared rules, plus independent risk adjudication. Shadow candidates cannot establish prevention. Unknown counterfactuals remain unknown, and downstream harm claims still need separately observed follow-up evidence.
- Operator setup, review, intervention, failed submissions, false blocks and maintenance are counted. The surrounding protocol also requires rework, escaped defects and cash/subscription/infrastructure costs. The observation window and acceptable extra effort are declared in advance.
- Internal success is not labeled cross-repository portability. `docs/strategy/PRODUCT.md` retains a separately scoped second-repository proof under I-F3; client portability still requires a second real client. Loka's materially different workflow remains a later target. Repository-wide documentation search found LokaCore only in current separation statements, superseded Q19, and dated strategy reviews; no remaining first-milestone LokaCore dependency was found.
- Read both prior portable-strategy reports. Q20 preserves their protected-promotion and observed-prevention corrections. Those reports approve their own named candidates, not this revision.

## Separate Ponytail Review

Applied `/Users/raymondluong/.codex/plugins/cache/ponytail/ponytail/4.10.0/skills/ponytail-review/SKILL.md` to the actual five-file documentation delta. **Lean already. Ship.** No unnecessary abstraction or machinery to remove. This complexity verdict does not override finding 1.

## Checks and limits

- Confirmed detached exact HEAD above and an empty working-tree status before and after review.
- `elixir bin/check_docs.exs`: **0 broken links**; AGENTS.md **481/800 words**.
- `git diff --check b3e2d6d e9408c9`: **passed**.
- Read the full review brief, repository instructions/index, relevant plan/strategy/product/validation/handoff sections, exact five-file diff, and both portable-strategy review records.
- No code edits, lane commands, full gate, implementation tests, CI, provider session or evaluation pilot ran. Only this report outside the checkout was written. Integration, candidate and PP worktrees were not edited.
