# ML-PG-CONTRACT independent design review

- Verdict: **correction**
- Candidate: `5eadca59dff738579200c7a3cc46d4129fe88e3e`
- Base: `063a4a65161a9120291ab749586c8d5e8ad03c5e`
- Reviewer: `agent:codex-gpt-6-astra/review-ML-PG-CONTRACT`
- Date: 2026-09-26
- Reviewed in clean detached `/private/tmp/ML-PG-CONTRACT-review`; no checkout edits.

## Blocking findings

### R1 — High: define the admitted base's equality with the accepted base

`docs/design/PORTABLE-GOVERNANCE-CONTRACT.md:17`, `:27`, `:31` allow the operator to supply an immutable admitted base, require its ancestry and the full changed path set, and say to recheck the current accepted base. They never specify the relation that must hold between the admitted base and the accepted old commit in the promotion claim. “Including the current accepted base” is not a predicate an implementer can enforce consistently.

Counterexample: accepted ref is A; an external branch has A→B with an unaccepted change outside this ticket's scope; the operator admits B; candidate C adds an in-scope change. Checking B→C ancestry/scope and CAS A→C can import B's unaccepted change. Alternatively, a candidate branched from an older admitted base can overwrite changes already accepted. The text does not explicitly rule out either interpretation.

Minimum correction: pin the protected accepted commit/revision at admission, require the admitted base to equal that commit, and require that same base at acceptance and promotion. Define scope against that base. A moved base requires an explicitly revised admission/new attempt and freshly checked/reviewed candidate descended from the new accepted base. If a different model is intended, state its exact predicate and full-delta evidence requirement instead. This must be settled in CONTRACT because exact-base semantics are its acceptance criterion.

### R2 — High: close the gap between authority validation, Git CAS and reconciliation

`docs/design/PORTABLE-GOVERNANCE-CONTRACT.md:13`, `:21`, `:27`, `:31` require current revisions and renewed evidence after policy/spec changes, but the only external compare-and-swap compares Git's old commit. No rule says whether authority revisions can change while a promotion claim is issued, or whether another promotion can proceed before the earlier effect settles.

Counterexample: promotion P validates candidate C under policy p and issues its claim; policy changes to p+1 (or the spec changes); P then executes A→C successfully because A did not move. Git's CAS cannot test policy/spec revisions, so simply re-reading them before the command still has a race. The promised current-evidence requirement is not defined at a safe linearization point. Separately, P can update A→C and crash before settlement; allowing Q to promote C→D before P reconciles makes the stated three-value reconciliation report P as a conflict despite its successful update.

Minimum correction: state a durable per-project pending-promotion exclusion that spans claim issuance through terminal settlement/reconciliation, including restart. Define which dependent authority changes are blocked during that interval (or require cancellation with proven writer quiescence before those changes can take effect). Admit no later promotion until the earlier one is reconciled. State the authority validation/claim transaction as the authorization point and preserve its dependencies until the CAS outcome is known. This needs a semantic invariant, not a new framework; CUSTODY/ACCEPTANCE can choose the implementation.

## Nonblocking refinements and decisions

- `:13`: make request identity explicitly principal/project scoped, or bind its authenticated actor into the digest and reject a different actor before returning a cached outcome. This makes authentication and retry interaction unambiguous; authentication alone is already required by `:25`.
- `:20`: when specifying the receipt schema, include candidate identity/commit and trusted check-run identity as well as the tree. Checks can inspect Git metadata; the existing requirement that a changed candidate gets new checks must remain enforceable even when two commits have the same tree. The current text already requires fresh checks and exact evidence; this is schema precision for CANDIDATE.
- `:48`: Option A is the minimum concrete deployment to prove exclusive write custody: a service-owned bare repository under an actual OS/process boundary that denies agent and check-worker access. A bare repository under the same unprotected user is insufficient. Option B is conditional on a particular host supporting the fixed namespace, exclusive credentials and atomic expected-old update; the document correctly does not claim that evidence exists. Provisioning location and the initial seed commit require operator choice before implementation/provisioning. That choice alone does **not** block approval of the abstract contract. R1 and R2 do.

## Verified strengths and current behavior

The two client mappings use the same protected facts without importing native session or completion fields (`:35`–`:42`). The document clearly marks itself proposed, distinguishes external integration from protected acceptance, and makes no spend, agent-launch or deployment claim. Authentication and reviewer independence are required rather than inferred from supplied labels. Candidate custody, trusted-policy checks, exact reviewed commit promotion, and old/new/third-value recovery are the correct boundaries once R1/R2 are explicit.

Current-lane claims at `:9` were traced to source:

- `lib/foundry/manual_lane/cli.ex:128`: admission resolves the supplied Git base; `:153`, `:166`, `:186` pass explicit packet/submit/review principal labels.
- `lib/foundry/manual_lane/backend.ex:68`, `:98`, `:147`, `:193`: claimed packets, delivered receipts and recorded reviews.
- `lib/foundry/work_packet.ex:15`, `:44`: stable packet, attempt, execution, effect, request and claim identifiers.
- `lib/foundry/manual_lane/replay.ex:21`: committed events rebuild kernel state.
- `lib/foundry/durable_store/protected/guards.ex:151`, `:164`, `:252`: recorded-principal independence across the attempt and receipt actors; comments expressly retain the isolation limitation.
- `lib/foundry/git_evidence.ex:33`, `:52`: candidate/base validation, clean checkout, exact HEAD and ancestry; CLI invokes it at `cli.ex:497`.
- `lib/foundry/manual_lane/server.ex:242`: seeds empty checks; `cli.ex:403` refuses a nonempty check set rather than running checks.
- `lib/foundry/manual_lane/cli.ex:248`: `git cherry` observation against the selected ref, without an acceptance write.

## Ponytail Review (separate complexity pass)

Lean already. No unnecessary implementation machinery was added. Preserve the safety requirements; R1/R2 need short invariants, not additional abstraction. Option A is the smaller implementation candidate once the operator chooses provisioning. No deletion recommendation.

## Checks, scope and limits

- HEAD exactly matched the packet candidate; `git status --porcelain` was empty before and after review.
- Diff: exactly the two owned documentation paths, 49 added lines; no code/test changes.
- `git diff --check <base>..HEAD`: passed.
- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS.md 481/800 words.
- Read the review packet, standing agent brief, documentation index/README, relevant repair-plan milestone rows and lane runbook; inspected the complete candidate diff and cited current paths.
- Static design review with concrete counterexample traces, not an implementation proof. No test suite, full gate, provider session, custody attack or promotion fault injection ran; no FR-08A rebind or implementation work was performed.

The lane verdict is to be recorded personally against this exact SHA. Correction is confined to the two contract invariants above; it does not authorize provisioning or settle the operator's repository-location choice.
