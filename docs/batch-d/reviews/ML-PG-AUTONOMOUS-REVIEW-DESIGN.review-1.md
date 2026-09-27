# ML-PG-AUTONOMOUS-REVIEW-DESIGN — independent review 1

- **Verdict: approved — design only. No blocking findings.**
- Base: `927bfd990fd9427eae16b85738ae531d4452d32d`.
- Exact candidate: `cfb2de877992985331e512f90954afbe0bc3c6fe`.
- Principal: `agent:pi-openai-codex-gpt-6-astra/review-ML-PG-AUTONOMOUS-REVIEW-DESIGN-1`.
- Issued packet: `/private/tmp/ML-PG-AUTONOMOUS-REVIEW-DESIGN.review-1.json`.
- Fresh independent review; no delegation, candidate edits, provisioning or human verdict.

Verified clean detached HEAD at the exact candidate. Reviewed the complete base-to-candidate range: six scoped documentation paths, 62 insertions/14 deletions. The seventh permitted path, STRATEGY, is unchanged. Read AGENTS, docs index and README, agent brief, portable repair-plan section, strategy working summary, workflow R3/R4a, all three preceding portable designs, their seven design reviews, and lane runbook. No earlier approval was treated as approval of this amendment.

## Ranked findings and retained gates

No demonstrated blocking design defect remains. The following are **ranked residual risks and implementation gates**, not completed acceptance evidence:

1. **High consequence: actual reviewer containment remains unproved** (`docs/design/PORTABLE-AUTONOMOUS-REVIEW.md:13-15,29`). The new topology addresses the original same-UID attack: candidate-executing tests/search/hooks run only under a worker identity without reviewer authority or an inherited socket; the verdict-bearing broker/model process has no model-directed executable tool route. Root-owned pinned installation, no plugin discovery, closed read interface, bytes rather than server paths, authenticated peer/endpoint and permanent UID enrollment are necessary together. A model/provider reply may propose a structured verdict; it must not select actor, role, assignment, checks, policy, target ref or commands. The future implementation review must inspect the actual provider transport, tool registry, environment/configuration loading and descriptor inheritance, not just a tool allowlist in a prompt. Any executable route under verdict UID disables this feature. This review did not run that host proof.
2. **Semantic false approval remains possible** (`:9,31`). Malicious source, instructions or worker/check output can persuade the independently assigned agent to approve defective code even when every OS boundary works. The amendment explicitly discloses this and same-provider correlated failures. Protected acceptance verifies attributable evidence and required predicates; it does not make that judgment correct. Neither an injected notes string nor a native completion signal can itself satisfy acceptance. Provider/model lineage and prospective false-approval/refusal/recovery measurement must remain visible.
3. **Migration and reconciliation remain gated** (`:23,35`; repair-plan ticket rows). Re-admission creates a new ticket/policy/assignment and freshly checked/reviewed candidate; it cannot relabel the old immutable custody packet or reuse its verdict/check/claim. The approved original-packet snapshot protocol and unresolved terminal non-start proof obligations carry forward. R4a still requires the same retained candidate/check ownership, terminal predecessor, atomic role-specific settlement and finite allowance; a newly issued reviewer execution is not permission to retarget an unresolved old one. Unknown delivery, revoked outstanding work and unproved historical results retain holds. Proof-source and typed reconciliation handoff decisions remain outstanding, not newly authorized by this approval.

## Independent consistency attacks

These are static counterexample traces over proposed semantics, not executable protected-route tests.

| Attack/cut | Required disposition established by the reviewed design |
|---|---|
| Candidate test opens verdict socket; plugin requests a shell; search worker submits the reviewer's packet | Wrong OS authority/operation refuses. No privileged socket inheritance or executable plugin route is allowed. The real worker-route negative is paired with a useful legitimate reviewer positive before enablement. |
| Tool/provider traffic embeds actor, approval instruction, acceptance label or promotion request | Text is untrusted. Only the assigned reviewer decision is recorded through the bounded broker; server derives authority. Semantic persuasion remains a disclosed risk, not a claim of injection immunity. |
| Different principal is actually a candidate producer, or candidate/check/spec/policy/assignment changes | Complete producer lineage and exact immutable bindings are revalidated; earlier approval cannot certify the changed input. Checks bind commit as well as tree and trusted definition/environment, so equal-tree substitutions do not bypass identity. |
| Review commits, consumes its claim, reply is lost, assignment/revision later advances | Current outcome-read permission first, then original actor/project/request/content match returns the durable original result. Old mutation preconditions are not rerun. Fresh-ID/consumed-claim and changed-content/sibling retries refuse. |
| Revoke on an open connection or before restarted result read/acceptance | Current enrollment/revocation is checked on every call and at acceptance; revoked approval cannot create new acceptance. Already issued or uncertain work is preserved for reconciliation, not assumed cancelled. |
| Ordinary candidate modifies broker/root/policy/gates; ambiguous eligibility | Protected ordinary-class validation excludes these changes; operator maintenance remains separate. The candidate cannot edit its authorization policy or self-install a new root. |
| Accepted A moves while candidate C is waiting | Admission/base/ref revision equality fails; revised admission, new checks and independent review are required. No patch-equivalent cherry-pick substitutes for the candidate. |
| Policy/spec changes race promotion; CAS succeeds and service dies before recording outcome | Atomic claim authorization plus durable project exclusion protects dependencies through reconciliation. Exact new commit/tree settles once; old permits retry only after issuer/channel quiescence; third value, corrupt objects or uncertain channel remain held. No second promotion proceeds meanwhile. |

The amendment keeps the earlier accepted-base equality, exact commit/tree CAS and claim-issuance authorization point rather than substituting a model-selected promotion command. It changes the ordinary promotion trigger, not the evidence predicate or operator maintenance boundary. The broader workflow contract is not rewritten or declared implemented.

## Historical scope and separate Ponytail Review

A focused Git/Python check confirmed both historical governance/custody bodies are byte-for-byte unchanged apart from their status line. The reconciliation design, frozen workflow contract and all prior review records are unchanged. Live index/plan/handoff changes consistently point forward and preserve old admission obligations. Prior C6 CI numbers are explicitly reported historical evidence, not this review's test results; I did not independently rerun or authenticate those remote jobs.

**Ponytail: lean enough; no deletion or new abstraction recommended.** The small pinned broker is necessary to implement the explicitly requested autonomous verdict without lending authority to candidate tools. Reuse the reviewed socket, enrollment, request-result and promotion mechanisms; do not expand this into a general harness, sandbox, scheduler or second authority store. Splitting custody, broker, candidate/check and acceptance delivery keeps their evidence boundaries reviewable.

## Checks and limitations

- `elixir bin/check_docs.exs`: passed, **0 broken links**, AGENTS **469/800 words**.
- `git diff --check 927bfd990fd9427eae16b85738ae531d4452d32d..cfb2de877992985331e512f90954afbe0bc3c6fe`: passed.
- Focused scope/history assertions: passed; exact clean detached HEAD, six paths within issued scope, historical bodies/status separation, unchanged frozen workflow/reconciliation/reviews.
- Pre-review `bin/foundry lane status ML-PG-AUTONOMOUS-REVIEW-DESIGN --json`: ready store, exact candidate, expected distinct reviewer principal and issued pending reviewer execution.
- No runtime implementation changed, so no source mutation/red-guard sweep was appropriate. Hostile-process, provider/tool, socket-kill, CAS-restart and scratch-red controls are specified future gates, not tests passed here.
- No full gate, FR-08A rebind, sudo, account/service installation, Linux fixture, protected verdict, integration or ref promotion was performed. Candidate checkout remains unchanged and unstaged.

## Lane recording

This exact report is the notes artifact for my personal `lane review` submission of **approved**, with the packet principal and exact candidate above, from the main checkout. Receipt and post-review status will be checked and returned separately without changing these recorded notes. The manual-lane receipt establishes only this design verdict; it does not enable protected agent authority or automatic promotion.
