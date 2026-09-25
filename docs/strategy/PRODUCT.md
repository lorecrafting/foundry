# Foundry product strategy

[Foundry](../../README.md) › [Docs](../README.md) › [Strategy](../STRATEGY.md) › Foundry product strategy

[Strategy brief](../STRATEGY.md) · [Validation](VALIDATION.md) · [Research register](RESEARCH.md) · [Meta-harness proposal](META-HARNESS.md)
**Status:** post-repair investment proposal under the existing authority contract.
> Moved from Pramāṇa on 2026-09-24 (commit `2ad8ed9`); Foundry maintains this copy on its own.

This was written as one half of a joint Pramāṇa/Foundry strategy and is now Foundry's
alone. The horizon (H0–H4) and gate (G0–G4) labels keep their pre-split meaning. G0 is
the repair entry gate: [FR-22](../REPAIR-PLAN.md#fr-22--prove-full-lifecycle-and-reconcile-operating-docs) accepted.

## Choices

| Choice | Proposed direction | Consequence |
|---|---|---|
| Foundry investment | Complete repair acceptance, then measure delivery, run a substitution check and improve only the demonstrated gap | Compose mature infrastructure where it passes Foundry's contract; do not rebuild generic agent/workflow/sandbox layers for ownership's sake |
| Long-term Foundry option | Portable model-directed execution/governance kernel, proved first on a second repository and later on a materially different authorized workflow | Preserve independence now; keep roles/workflows configurable outside the protected authority core; delay multi-tenant platform work until demand is demonstrated |

Foundry's proposed advantage is controlled delivery with understandable failure and
recovery, across permitted providers, without requiring the operator to babysit
ordinary work. A multiplexer, model gateway, coding agent or generic durable workflow
runtime alone is not that product. Foundry should compose those systems when they
satisfy its contracts and should stop building any layer an external product can do
better without weakening authority or evidence. The sections below
own the boundary and investment logic.

## Mission and boundary

Foundry is a trusted execution and governance kernel for model-directed work. Given a
bounded objective, capable models may propose how to decompose and perform the work;
Foundry supplies observable progress, controlled authority/expenditure, attributable
evidence, acceptance and recoverable failure. Software engineering on Foundry itself is the
first workload and first customer, not the permanent role/workflow model.

The longer-term product option is the same dependable kernel across repositories and
across materially different workflows within one project, without Buddhist-domain or
Pramāṇa database dependencies. Independence is architectural; external demand is still
unproved. Scope is not limited to one operator, one machine or one repository, but a
new repository or non-software workflow pilot needs its own approved project scope and
policies; FR-22 is not blanket authorization for expansion.

Keep the standalone OTP system. It may require appropriate local libraries and
protected host provisioning; “standalone” does not mean zero dependencies, zero
operations cost or an unmeasured two-second test cycle. Every supervised project must
build and run without Foundry. A Foundry assignment may invoke authorized project
commands in an isolated environment; Foundry's authority store must never become a
supervised project's database.

## Repair acceptance is the entry gate, not another initiative

[REPAIR-PLAN](../REPAIR-PLAN.md) and
[WORKFLOW-CONTRACT](../WORKFLOW-CONTRACT.md) govern. The former owns
status and ordering; do not copy its mutable ticket states into this strategy.
FR-22 owns end-to-end closure and unresolved limits, including a real autonomous
kernel repair under unchanged protected-root policy. Green component CI alone is
not that acceptance. This strategy neither closes tickets nor suspends obligations.

| Existing repair authority | Product implication after acceptance |
|---|---|
| FR-07/08 and the workflow contract | Consume the accepted transactional state, command and replay interfaces; do not build a parallel event store |
| FR-09/15a/16 | Provider use must satisfy installed harness, isolation, entitlement and bounded switching evidence |
| FR-10/11/12 | Lifecycle ownership, reconciliation and scheduling are foundations to use, not essay-derived replacements |
| FR-13/14/17 | Candidate, review, check, integration and activation identities remain distinct |
| FR-18/19/20/21 | Use honest projections, retention, constrained improvement and build provenance |
| FR-22 | Require the scenario evidence and explicit unsupported cases before post-repair autonomous product work |

A discovered contradiction returns to the owning contract through review. It does
not authorize a strategy rewrite of the repair queue or an operator-only kernel
that permanently removes the agreed autonomous repair capability.

## One operating model, not several overlapping stacks

Consolidate harness/graph/loop, the four-layer compound stack and the six-layer OS
into six responsibilities: **contract, context, tool boundary, durable state,
evidence, recovery**. These are a review vocabulary, not six new services.

The workflow kernel decides domain transitions; the protected verifier owns safety
and authority checks. Middleware can shape context or diagnostics inside those
boundaries. A plugin, model response or general evaluation tool cannot be allowed
to replace the checks that constrain it. The current source still uses OMP through
Herdr, but the durable execution boundary should be harness-neutral. Pi remains the
preferred first replacement agent candidate; before writing a custom bridge, compare
direct pinned Pi RPC with pinned Jido.Harness/ACP behind the same Foundry contract.
Neither path is adopted until FR-09/15a conformance and any OMP-specific governing-contract
text are explicitly revised and re-reviewed. Herdr remains initial optional presentation.

A subagent used as a tool returns bounded findings while the parent retains task
ownership. A lifecycle handoff changes the responsible assignment/role with durable
identity. Neither gains permission to accept its own work. Review must be independent
of the maker's authority and have the exact candidate, contract, source context and
raw evidence it needs—not merely a diff and one suggested test command.

## Models direct; the kernel governs

Increasing model capability should shrink Foundry's hard-coded intelligence rather than
eliminate its protected kernel. Let models propose decomposition, temporary role names,
workflow topology, context/tool requests, execution profiles, tests, reviewers and
correction strategies. Do not invest in a large permanent planner hierarchy, fixed role
taxonomy or rule engine whose main job a stronger model can perform from current state.

Keep deterministic or protected the things whose truth cannot safely depend on the
planner: admitted objective/policy revision, principal and assignment identity,
capability grants, durable state transitions, request/budget accounting, effect claims
and duplicate suppression, exact artifact identity, check/review provenance,
independence requirements, acceptance predicates, reconciliation and promotion.
Protected policy may require gates omitted by a proposed workflow and a plan cannot
weaken them. A model may propose completion, retry or publication; receipts and policy
authorize the corresponding effect. Independence follows durable principal/authority
lineage and candidate ownership, not a fresh role name, session or model.

Post-repair workflow portability should be project-configurable rather than role
hard-coded. A project/workflow definition may declare requested roles, capability
requirements, context rules, evidence types, acceptance profile and project adapters.
Those declarations are requests: effective capability is the intersection of protected
operator policy, project scope, workflow/role allowance and the specific assignment.
Repository-controlled configuration can never grant itself secrets, billing authority,
arbitrary shell/network access or publication power.

For future non-code workflows, effective policy may also need attributable **observation
provenance**: what protected data an execution or artifact actually consumed can matter to
whether it may later be shared or published. Cloudflare OS provides useful design pressure
here, but this is not a current repair-time ontology change. A future ObservationReceipt
should begin as evidence/provenance and earn any protected policy role through a separate
bounded experiment; connector/provider claims must never become self-authenticating
Foundry authority.

Pin every admitted workflow definition/revision to the run that used it. If a model or
project changes the plan mid-run, record and admit a new revision instead of rewriting
history. Child work and sub-workflows inherit parent scope and budget ceilings unless
protected policy narrows them; composition cannot mint authority. Favor a small
vocabulary such as sequence, bounded parallel work, gates, handoff, correction and
sub-workflow invocation over an unconstrained executable workflow language. Generalize
only from observed needs.

This permits different workflows inside one project. For example, a future Lokacore
software workflow could use isolated Git/shell/compiler capabilities, while an approved
RPG content-authoring workflow could expose only its typed Builder API, simulations and
certification. The same model could serve as engine developer in one assignment and
quest author in another because authority follows the assignment, not the model name.
Released game/runtime artifacts should remain independently useful without Foundry or an
LLM. This is a future portability target, not part of the current repair scope.

## Replaceable controllers over one authority plane

Post-repair portability should not require Foundry to own one permanent orchestration
runtime. The default workflow kernel can remain the reference/local controller while
Cloudflare OS, AX, Pi, Claude/Codex harnesses or future systems drive the same protected
facts through a narrow OrchestratorAdapter.

Use two paths:

- **authority:** semantic, durable, idempotent commands for admission, grants, execution
  issuance, evidence binding, consequential effects, acceptance and promotion;
- **observation:** high-volume non-authoritative model/tool/runtime/controller telemetry
  with common correlation IDs and optional OpenTelemetry export.

Controllers consume facts/eligibility and propose what to do next. They do not receive a
generic protected `advance()` operation and their own "completed"/"approved" states do not
become Foundry facts automatically. A post-repair subscription surface (I-F5, O1/O2) would let deterministic
controller code wait without repeatedly waking a model to poll child status.

This makes Foundry a neutral referee for workflow experiments: keep authority and
acceptance fixed, swap controllers, and compare accepted-outcome correctness, token/cost
usage, latency, correction tax and operator effort. See
[Orchestrator boundary](../design/ORCHESTRATOR-BOUNDARY.md).

## Positioning: own the contract, not commodity infrastructure

Foundry must earn its custom infrastructure. Its durable product boundary is the
authority/evidence contract around model-directed work: admitted intent and capability,
durable identities and budgets, exact external-effect accounting, exact artifact/evidence
binding, independence constraints, acceptance, reconciliation and controlled promotion.
Agent loops, software-factory UIs, workflow runtimes, sandboxes, policy languages and
model routers are implementation choices unless the governing contract proves otherwise.

Separate three replaceable boundaries that are easy to conflate. An
`OrchestratorAdapter` answers how an external controller consumes Foundry facts and
proposes work. An `ExecutionBackend` answers where/how admitted code runs. A
`ResourceAdapter` or capability broker answers what external resources that execution
may read or affect without gaining ambient credentials. The controller seam may be implemented by the default Foundry kernel,
Cloudflare OS, AX, Pi or future orchestrators. Execution may use a local Linux worker,
AX/Agent Substrate, Cloudflare Dynamic Workers/Sandbox or future runtimes. Resource
mediation may use provider-specific Gatekeeper-like brokers. None may create Foundry
grants, settle budgets from self-reported counters or accept its own output. The [AX/Substrate](../design/AX-SUBSTRATE.md) and
[Cloudflare OS](../design/CLOUDFLARE-OS.md) reviews record the current evidence
and non-authority constraints.

Before post-repair work adds or substantially extends one of those implementation layers,
run a bounded substitution evaluation against the strongest available alternative.
Current candidate classes include Warp Factories for software-factory orchestration,
LangGraph for agent/workflow runtime, Restate/Temporal/DBOS for durable execution,
AX/Agent Substrate and Cloudflare execution primitives behind a common ExecutionBackend,
Gatekeeper-like brokers for narrow resource/effect mediation, Dagger plus
OS/container/micro-VM primitives for execution isolation, and OPA/Cedar for bounded
authorization-policy evaluation. These names are candidates, not dependencies.

A substitution evaluation compares the actual Foundry cases—not feature lists—including
lost acknowledgments, duplicate delivery, unknown side-effect outcomes, durable budgets,
credential separation, exact candidate/receipt binding, independent review, mandatory
gates, cancellation, restart/replay, positive useful completion, local operating burden,
privacy/licensing and reversible migration. Adopt a candidate only where it lowers total
burden without weakening those properties. If it fully satisfies a layer, remove or avoid
duplicative Foundry code. If a future product satisfies the entire useful contract, using
it instead of Foundry is a valid success outcome.

This is also the future-proofing rule: model capability growth should delete planning
heuristics; infrastructure maturity should delete infrastructure code. What should remain
stable is the contract that distinguishes a proposal from authority, activity from
evidence and completion claims from accepted outcomes.

## Current host path and why execution isolation matters

Today no automatic agent route exists: the Herdr/OMP path was deleted on 2026-09-23
([plan amendment C1](../REPAIR-PLAN.md#clean-room-amendment)) and the manual lane launches
nothing. Before deletion it was fail-closed, because it had not proved subscription and
billing isolation, and the path under that gate was host-based. Herdr opened a terminal
pane at the assignment checkout and started OMP there as a host OS child. Foundry tracked
pane, process and process-group identity for ownership and cleanup, but that is not
container or credential isolation. The [strategy brief](../STRATEGY.md#current-execution-baseline-nothing-launches-the-old-path-was-host-bound)
has the current baseline.

A worktree keeps concurrent Git changes separate; a pane keeps sessions distinguishable;
a process group makes descendant cleanup safer. None limits a shell-capable worker to the
checkout, removes the host principal's readable files, or disables arbitrary network
egress. Restoring automatic execution therefore requires the FR-09/15a security boundary,
not reviving the deleted launch path.

Dagger is conceptually above Docker rather than a Docker replacement. Docker/Podman/etc.
supply OCI container execution; Dagger can programmatically compose those containers,
inputs, services, commands, caches and artifacts. Foundry may use Dagger to reduce
execution plumbing, or use a direct container/micro-VM adapter if that is smaller and
easier to verify. In either case, the same credential, network, filesystem, resource,
cleanup and useful-completion conformance tests apply.

A sovereign in-house option is intentionally narrower than building a container engine:
own a small versioned sandbox-manifest protocol, policy compiler/launcher and conformance
suite, while delegating enforcement to Linux primitives or a pinned minimal helper. For
shell-capable software workers, the baseline policy should include a credential-free
dedicated identity, cleared environment/file descriptors, no host home/keychain/SSH or
runtime sockets, an explicit workspace and ephemeral home/tmp, default-deny networking,
resource/PID/time ceilings, complete descendant cleanup, `no_new_privs`, capability
dropping, syscall filtering and stackable filesystem/network restrictions such as
Landlock where supported. Exact policy/rootfs/input/argv/output identities become
receipts.

Because the current operator host is macOS, the simplest strong boundary may be a
Foundry-controlled Linux worker VM with per-execution Linux sandboxes inside it. Apple
Virtualization.framework supports Linux guests. Keep operator credentials and normal host
files outside the VM; transfer only the exact workspace/input and return patches/artifacts.
This provides defense in depth: an inner sandbox failure reaches a sacrificial worker
guest before it reaches the operator host. A direct Linux host can use the same sandbox
contract without the outer VM.

Do not confuse source ownership with security quality. A tiny in-house launcher can be
easier to audit than a large platform, but writing raw sandbox mechanisms creates subtle
mount, file-descriptor, namespace and privilege bugs. Prefer composing kernel enforcement
and, where useful, a pinned/mirrored low-level helper. The security update path remains
mandatory even for vendored code.

## Elixir control plane; OS/sandbox security plane

Retain Elixir/OTP for long-lived coordination, supervision, workflow state/replay,
assignment lifecycle and recovery. Do not use BEAM process separation as the security
boundary for arbitrary agent-controlled tools.

Hard process/filesystem/network/resource boundaries belong to the host or a proven
execution backend. On Linux, evaluate native primitives such as namespaces, cgroups,
seccomp and Landlock, normally through a container/sandbox/micro-VM layer rather than a
new Foundry reimplementation. Non-Linux hosts need equivalently tested mechanisms.
Dagger is worth a bounded evaluation because it exposes typed execution objects and an
Elixir SDK, but its current Elixir SDK is beta and Dagger must still prove Foundry's
credential, egress and cleanup requirements before adoption. Dagger-managed secrets do
not authorize reusable model/provider credentials inside candidate-controlled execution;
preserve the protected authentication boundary unless a reviewed replacement proves the
same or stronger separation.

The execution backend therefore remains replaceable beneath the Elixir authority/control
plane. Elixir is the current control-plane implementation, not the security boundary or
the product moat. Foundry should specify *what must be isolated and evidenced*, not own
every kernel mechanism used to achieve it, and should replace even its own infrastructure
when measured substitution evidence justifies that change.

## Jev as a fast semantic layer, not authority

The current Stage-A assessor already captures the appropriate Jev boundary. TypeSafe's
System One guidance keeps deterministic control flow and side effects in code while
models answer narrow typed questions with probabilities/confidence. If held-out
evaluation supports it, Jev can become a cheap reflex layer for context ranking,
diagnostic triage, progress/stuck signals, duplicate findings, risk classification and
execution-profile recommendations.

Those signals remain advisory. Deterministic policy decides whether a confidence range
may trigger a low-risk automatic path, require stronger-model/human verification, or do
nothing. Jev cannot establish entitlement, spend, durable state, reviewer independence,
safe retry of an unknown effect, acceptance or promotion. Keep a deterministic fallback
and a replaceable provider boundary because Jev is currently early access.

## Project-defined roles, surfaces and escalation

The long-term product should not encode today's `developer → reviewer`
workflow as the protected ontology. The detailed direction is recorded in
[Project workflow profiles](../design/PROJECT-WORKFLOW-PROFILES.md).

Projects may describe versioned RoleSpecs and request scoped tool/API surfaces, context,
evidence adapters and workflow shapes. Foundry's protected kernel admits an exact
CapabilityGrant no broader than operator/project policy.

Loka is the strongest concrete design case currently available because its authoring
architecture deliberately separates layers:

- content/world builders can be very powerful over L3–L6 through a typed Builder API;
- those builders should have no ambient engine-source or arbitrary-shell authority;
- missing semantics become CapabilityProposal/escalation;
- engine-capability developers receive separate L2 source scope and stronger checks;
- semantic reviewers remain read/simulate-only;
- release roles operate only on exact certified artifact identities.

This is more useful than adding a `mud_builder` branch inside Foundry code. The protected
kernel should understand assignments, principals, capability grants, evidence,
independence and acceptance; `mud_builder` is project vocabulary supplied by a
ProjectProfile.

Current runtime code is not yet role-agnostic: software-specific launch roles and
handoff/review phases remain part of the active repair baseline. Post-repair portability
must remove those assumptions only after the fixed workflow is proven and a materially
different typed-content workflow demonstrates the generalization.

## Foundry as an experimental workflow kernel

The long-term boundary should permit controlled comparison of planning/workflow strategy,
model/profile, harness, context policy, tool surface, reviewer topology and concurrency
without changing the protected authority/evidence rules for each experiment. Compare
matched task classes by accepted outcomes, correctness, operator effort, correction tax,
latency, token/context use, provider-reported cost where available and recovery burden;
do not optimize raw token count or throughput in isolation.

Vertical work slices are a useful current planning hypothesis, not Foundry ontology. A
PM/Shaper may use slices to turn an objective into human-recognizable outcomes and then
propose bounded tickets, but a future goal graph, blackboard, dynamic DAG or repeated
next-best-action planner should be able to use the same admission boundary. Human work
views and compact continuity capsules should remain replaceable projections over durable
state and evidence. The detailed boundary is in
[Replaceable planning strategies](../design/PLANNING-STRATEGIES.md).

## First post-repair investment: useful context and honest feedback

Measure where the operator loses time, then try one bounded improvement. Candidate
I-F1 compiles task-specific context from the small repository router, governing
contract, active source/diff, dependencies, relevant rules and evidence references.
Routine tasks need less history than architecture work, but never zero constraints.

Keep compact observations with a route to underlying evidence: command, environment,
source revision, actual work performed, exit status, diagnostic locations and the
full artifact reference. A successful command that performed no expected work must
not count as productive completion. An empty queue can be healthy and idle; distinguish
**service health**, **eligible work**, **work attempted** and **accepted outcomes**.

Use [Foundry observability](../OBSERVABILITY.md) to measure the complete
resource path from task/attempt/execution through model requests, tools, corrections,
review and final acceptance. Preserve source-qualified token/cache/cost/context data when
the selected harness exposes it, plus human steering/review/recovery effort. Converge
runtime producers on one canonical observation envelope and an Erlang `:telemetry` seam,
with durable local analytics and optional OpenTelemetry traces/metrics as separate sinks;
OpenTelemetry is not the workflow/effect ledger. Optimize accepted outcomes per operator
hour and comparable per-accepted-outcome costs; raw token reduction is not a success
metric when it increases defects, correction cycles or operator attention.

Read-cache receipts are hints, not authorization or durable memory. Recheck the
file hash/revision before relying on cached content, and invalidate on external
changes. No universal 500-token ceiling or fifteen-line diagnostic can fit every
contract. Size limits must preserve decisive errors and mandatory context.

## Memory: evidence first, projections second

Use the accepted local transactional authority store. Diagnostic logs and retrieval
indexes are not competing sources of authority. Separate these record types:

| Record | Treatment |
|---|---|
| Raw command, artifact and test evidence | Retain under the owning security/retention policy with identity and access controls |
| Current state | Rebuildable projection of acknowledged decisions and external receipts |
| Task decision | Attributed decision with scope, rationale, author/authority, date and supersession |
| Lesson or skill candidate | Hypothesis until reviewed, tested and approved for the relevant scope |

Resolve the notebook's “summarize everything” versus “never summarize” conflict:
**retain required evidence; summaries are replaceable, attributable projections**.
Read-time selection can use those projections plus original evidence. A summary
cannot mint a passing receipt, authorize a transition or erase an unresolved failure.
“Save everything” is not permission to persist secrets or private inputs forever.

Promote useful lessons through failure → investigation → verified evidence → reviewed
rule/skill → relevant consultation. Automate proposals where authorized; do not let
a model silently make global policy from one anecdote. Measure recurrence reduction
and false alarms. Personal, task, project and shared scopes need explicit access and
promotion boundaries, even before any multi-user product exists.

A supervised project's own research notes remain separate from canonical sources and
from this engineering ledger. Similar provenance concepts do not justify shared tables,
credentials, embeddings or a required memory SaaS.

## Providers, budgets and recovery

Repository guidance applies to Claude, Gemini, DeepSeek, Codex and other providers.
That does not make all profiles eligible for automation. The current repair contract
permits only explicitly authorized subscription routes; paid OpenRouter/DeepSeek
use remains manual unless the operator changes policy through the proper authority.
No eligible route means wait with a reason. Provider choice, harness implementation
and terminal/session backend are three different decisions.

Do not freeze model brand names or price tiers into strategy. Evaluate permitted
profiles by task success, review effort, latency and total cost. Reviewer capability
must fit the risk; a cheaper model is not automatically an adequate grader. A new
API gateway is an optional dependency, not a reason to route around the selected harness,
protected request path or billing isolation. A supervised project's user-facing model service needs its
own approved policy; builder subscription permission does not authorize serving public
product queries.

Use the accepted budget ledger across retries, child work, handoffs, restarts and
switches. Preserve unknown outcomes for reconciliation; a context reset or profile
change cannot refill a budget. Reserve bounded recovery capacity and stop safely
before exhaustion. A model may propose completion or stopping; acceptance requires
evidence, while blocked, cancelled or budget-exhausted states are valid non-success
outcomes. Task prompts never override higher-priority safety or operator authority.

## Improve tools without replacing the system

Candidate I-F2 evaluates one mechanism at a time: structured diagnostics, AST outlines
and previewed edits, duplication checks, architecture-boundary checks, or UI test
capture. Retain ordinary source files and human-readable diffs. A syntactically valid
AST rewrite is not semantic correctness; an empty rewrite must report no change.
Browser/vision checks supplement functional and accessibility tests, not certify them.

Prefer small composable tools, but unrestricted evaluation inside a production BEAM
is not a safe shortcut. Evaluate in isolated workers with bounded interfaces.
The [research register](RESEARCH.md) treats Elixir Vibe packages as candidates, not
an adopted dependency set. No new framework earns a place without measured benefit
and an explicit maintenance/security cost.

## Portability and the Superlogical option

Candidate I-F3 first proves the accepted software workflow on one operator-selected,
second repository (not Foundry itself) and compares the result with the best practical off-the-shelf
alternative for the same job rather than assuming custom Foundry orchestration is needed. Identify project-specific commands, roles and evidence adapters
without generalizing the entire platform. After that baseline, a stronger portability
proof is a separately authorized workflow with a materially different tool/evidence
surface in the same project, such as typed content authoring rather than Git/shell.
Evaluate onboarding effort, reliability and net operator effort before pursuing
multi-user hosting or a commercial package. This is a separate product hypothesis,
not a permanent support feature of any one project.

Retain Superlogical as the preferred **future candidate to evaluate** for session/
presentation integration, not a completed or feature-equivalent Herdr replacement.
Its public roadmap is not backend conformance evidence. I-F4 requires a real
available interface, ownership/cleanup and reconnect tests, failure reconciliation,
headless operation, credential/billing separation, licensing review and a reversible
cutover. If it changes execution rather than presentation, return to FR-09/15a's
contract boundary. Do not block the first supervised workflow on its availability.

## Prevent endless infrastructure work

After H0, protect one primary research-product slice and allow one bounded Foundry
improvement alongside it, subject to operator capacity. Give every improvement a
baseline, success condition, effort cap and stop decision. If it does not improve
accepted delivery after review/rework/maintenance are included, revert or defer it.
Keep reliability fixes prioritized, but require evidence for “this platform will
make everything faster.” Do not let a second-repository experiment silently become
a generalized multi-tenant rewrite.

## Candidate initiatives

Initiative IDs are stable planning handles, not tickets. I-F initiatives are Foundry's;
the I-P initiatives of the pre-split roadmap belong to Pramāṇa and do not apply here.

For Foundry initiatives, **compose before build**. Before adding substantial custom
orchestration, durable-execution, policy or sandbox infrastructure, perform a bounded
substitution check against the strongest current external candidate and the exact
Foundry authority/evidence contract. A candidate that satisfies the contract with lower
total burden should be reused; existing custom code is not a reason to reject it.

#### I-F1 — task context and compact evidence

**Outcome:** agents resume and finish bounded work with less operator intervention.
**Evidence:** context-reset/restart cases, evidence rehydration, changed-file cache
invalidation, honest idle states and matched-task effort comparison.
Reorientation-tax measures per
[OBSERVABILITY](../OBSERVABILITY.md) belong here. **Dependencies:** G0 and accepted state/receipt interfaces. **Excludes:** another
state store, giant mandatory prompt or a fixed tiny context cap that drops constraints.

#### I-F2 — one tooling/quality improvement at a time

**Outcome:** reduce an observed class of rework, preferably by composing a proven
external mechanism when it satisfies the contract. **Evidence:** representative tasks,
false-positive and maintenance cost, full diffs, failure/no-op cases, rollback and a
documented substitution comparison when overlapping mature infrastructure exists.
**Dependencies:** G0 plus a measured bottleneck. **Excludes:** bulk adoption of AST,
lint, replay, gateway and orchestration packages as one “ecosystem upgrade,” or custom
infrastructure justified only by ownership.

#### I-F3 — project and workflow portability

**Outcome:** Foundry works on a second approved project,
then demonstrates that project/workflow roles and tool/evidence surfaces are not baked
into the protected kernel.

**Evidence:** first prove an accepted software change with separate setup/commands,
recovery, operator effort/support burden and comparison with the best practical
off-the-shelf software-factory alternative. Then, under separately authorized scope,
prove a materially different typed-content workflow such as Loka:

- world/quest builder receives only its ProjectProfile-declared Builder/Lab surface;
- engine-source/shell operations are denied;
- MISSING_CAPABILITY escalates to a separate engine-capability assignment rather than
  expanding the builder's grant;
- mandatory content certification cannot be removed by the project/model plan;
- reviewer independence is checked by durable principal/candidate lineage;
- context/evidence routing changes by RoleSpec while protected authority semantics remain
  invariant.

Use [Project workflow profiles](../design/PROJECT-WORKFLOW-PROFILES.md) as the
post-repair design target and [Validation](VALIDATION.md#foundry-cross-workflow-portability-validation)
for falsification cases.

**Tracked follow-on:** LLM-proposed workflows, progressive admission and safe
replanning (pre-split issue #47, not yet re-filed in Foundry). After the software baseline,
prove both next-step and composed work through the same bounded semantic interface, then
a separately authorized typed-content workflow. The model supplies planning intelligence;
a catalog, structured diagnostics/lab, semantic diffs and safe amendments make its
commitments usable and testable. A complete upfront graph or universal workflow DSL is
not required. Claimed hard bounds need actual protected enforcement and evidence.
Detailed design is in [Planning strategies](../design/PLANNING-STRATEGIES.md#31-llm-first-planning-and-progressive-commitment).

**Dependencies:** G0, a bounded allocation and separate project/workflow authorization
under the governing contract. **Excludes:** multi-tenancy, self-granted capabilities,
a general workflow platform before evidence, or assumed demand from one successful demo.

#### I-F4 — future session-backend conformance

**Outcome:** evaluate a reversible Superlogical integration when a usable interface
exists. **Evidence:** installed backend tests against [the Foundry requirements](#portability-and-the-superlogical-option),
including headless behavior and rollback. **Dependencies:** G0, actual availability
and approved interface/security scope. **Excludes:** treating roadmap promises as
Herdr parity or making any project's delivery depend on the migration.

#### I-F5 — Core/Standard Controller split and substitution experiments

**Outcome:** the O0–O4 ([orchestrator boundary](../design/ORCHESTRATOR-BOUNDARY.md)),
A0–A4 ([AX substrate](../design/AX-SUBSTRATE.md)) and C0–C3
([Cloudflare OS](../design/CLOUDFLARE-OS.md)) ladders run **one at a time** under
FOUNDRY's one-bounded-improvement rule, so the Core/Standard Controller distribution is tested
rather than assumed. **Evidence:** per ladder, a bounded workflow run against the seam it
names, plus the conformance list that ladder declares. **Dependencies:** G0, the I-F3 software
baseline. **Excludes:** refactoring protected authority out of the kernel before FR-22; more
than one ladder active at once; treating any "first experiment" claim in the positioning
documents as a commitment.

**Tracked workflow learning loop:** workflow analytics and governed
optimization (pre-split issue #48, not yet re-filed in Foundry), consuming the I-F3 track's automatic
instrumentation and amendment contract. Start with reproducible, scoped read-only queries
and exact contributing runs; then observed critical-path/outcome analysis and one bounded
workflow experiment with fixed acceptance requirements. Support dynamic execution history
without a universal prospective DAG. Compare whole accepted-outcome cost, quality and
operator effort, including failed/unfinished work and measurement overhead; preserve
unknowns and distinguish observations from causal claims.

Both issues are post-repair delivery tracks, not new FR tickets or parallel active ladders.
Their runtime work requires the accepted FR-18/FR-20 and relevant controller interfaces;
no current FR ticket depends on these implementations. #48's documentation-only A0 slice
separately tracks the coordinated FR-18B/FR-20 ownership amendment for observability
convergence steps 6/7. It may be prepared during repair but is not deemed applied by this
roadmap. See [tracked delivery and handoff](../design/PLANNING-STRATEGIES.md#tracked-delivery-and-handoff).
Merging a planning PR closes neither implementation issue and enables no execution.

## Open decisions

IDs continue the numbering of the pre-split decision register. New decisions go in the
[dogfood log's decision table](../batch-d/DOGFOOD-LOG.md#operator-questions-and-decisions).

| ID | Decision / recommended default | Owner role | Required before |
|---|---|---|---|
| D9 | Select a second repository, success criteria and explicitly authorized project scope for the first Foundry portability proof; any later materially different workflow receives its own explicit scope/capability authorization | Operator and that repository's owner | I-F3 |
| D10 | Decide a session-backend cutover only after actual conformance; Superlogical remains a future candidate | Operator and protected-boundary reviewer | I-F4 activation |

| Risk | Response / evidence owner |
|---|---|
| Self-improvement corrupts rules or evidence | Accepted protected verifier, scoped promotion and traceable supersession |
