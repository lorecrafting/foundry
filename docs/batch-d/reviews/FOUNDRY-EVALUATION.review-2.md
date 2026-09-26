# Q20 evaluation correction re-review

**Verdict: approved.** Exact candidate **`7bdfc06350b8ee40dae4d9e049078c60a4bf0c23`** closes the P2 finding and addresses the P3 note from the review of `e9408c92e8fe2a3bfce6b0be74d44630857a67c9`. No remaining correction is requested.

## Finding disposition

- **P2 closed:** `docs/strategy/VALIDATION.md:61–69` requires actual acceptance under the assigned workflow plus independent acceptable-outcome adjudication through follow-up. Acceptable-but-blocked and never-eligible shadow candidates are reported separately. The general scorecard at lines 83–86 and `docs/REPAIR-PLAN.md:155` now use the same outcome population.
- **P3 addressed:** `docs/strategy/VALIDATION.md:53–55` records the exact running Foundry service revision for every governed trial and discloses upgrades between matched trials.

Native acceptance is observed on a declared isolated evaluation ref with the ordinary PR/CI protections. It is explicitly distinct from Foundry's protected accepted ref and from later reviewed live integration. The correction does not weaken the protected promotion requirements or turn a candidate-quality judgment into observed acceptance. Prevention still requires actual matched native acceptance of the unsafe input; shadow work cannot establish it, and downstream harm remains a separately evidenced claim.

The Q20 handoff retains the internal pilot and keeps LokaCore separate. C2 ordering and the portable milestone remain unchanged. This approval concerns the evaluation protocol's wording, not proof of product value or runtime enforcement.

## Checks and limits

- Reviewed the exact `e9408c9..7bdfc06` delta: two live-document corrections and the preserved first review record; also read the plan row, validation protocol/scorecard and Q20 handoff.
- `elixir bin/check_docs.exs`: **0 broken links**; AGENTS.md **481/800 words**.
- `git diff --check e9408c9 7bdfc06`: **passed**.
- Separate Ponytail Review of the correction: **Lean already. Ship.** No unnecessary machinery or safe substantive deletion identified.
- Detached `/private/tmp/foundry-evaluation-review-2` stayed clean at the exact SHA above. Only this report outside the checkout was written.
- No lane command, code edit, implementation test, full gate, CI, provider session or evaluation pilot ran. This is a documentation approval, not a lane verdict.
