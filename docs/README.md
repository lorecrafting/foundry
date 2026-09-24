# Foundry documentation

Foundry is an independent OTP execution and governance system. [The overview](../README.md) describes
its implementation inventory and important containment limits. Neither a historical
review nor a model-free CI result establishes that live promotion or provider execution
is enabled.

Read the [strategy working summary](STRATEGY.md#working-summary) once for overall
direction: model-directed work under dependable authority, reused harnesses, independent
evidence and useful recovery. The strategy is context; the repair plan and workflow
contract still govern implementation.

## Start by the task

| Task | Read |
|---|---|
| Change any Foundry code | [Boundary rules](BOUNDARY-RULES.md) first — twelve decoupling rules, each naming the test or review that enforces it |
| Write Elixir code or tests | [Elixir conventions](ELIXIR-CONVENTIONS.md): language, Mix and ExUnit rules, including the portable temp-directory idiom |
| Delegate Foundry work to an agent | [Agent brief](AGENT-BRIEF.md): the standing clauses every task prompt inherits; repository-wide agent rules are in [AGENTS.md](../AGENTS.md) |
| Run a ticket through the manual lane as operator | [Lane runbook](batch-d/LANE-RUNBOOK.md): start the lane daemon, admit, packet, submit, review, settle, recover |
| Understand investment priorities or evaluate architecture/tooling | [Foundry strategy brief](STRATEGY.md), then the relevant governing repair contract |
| Read the product strategy, candidate initiatives (I-F1–I-F5), validation plan or research register moved from Pramāṇa | [Product strategy](strategy/PRODUCT.md), [validation](strategy/VALIDATION.md), [research register](strategy/RESEARCH.md), [meta-harness proposal](strategy/META-HARNESS.md) |
| Understand Foundry's ecosystem position, what the kernel must own, and what should remain substitutable | [Ecosystem boundary and positioning](design/ECOSYSTEM-BOUNDARY.md), then [Foundry strategy](STRATEGY.md) and the governing workflow/repair contracts |
| Understand how Cloudflare/AX/Pi/Claude/Codex or another controller should drive Foundry without becoming authority | [Orchestrator boundary](design/ORCHESTRATOR-BOUNDARY.md), then [Project workflow profiles](design/PROJECT-WORKFLOW-PROFILES.md), [Observability](archive/OBSERVABILITY.md) and the governing workflow contract |
| Start or check orchestrator-boundary step O0 (which workflow calls cross protected authority, and what could move above Core) | [O0 authority inventory](orchestrator/O0-AUTHORITY-INVENTORY-2026-09-22.md). It is an inventory taken at `6bc015ed` and changes no behaviour; read it after [Orchestrator boundary](design/ORCHESTRATOR-BOUNDARY.md) |
| Evaluate or implement the Pi replacement candidate and Claude-like ergonomics | [Pi harness design](design/PI-HARNESS.md), then the [checkpoint F feasibility record](archive/fr-09/checkpoint-f-feasibility.md), its [independent blocker review](archive/fr-09/checkpoint-f-review.md) and [independent correction PASS](archive/fr-09/checkpoint-f-rereview.md), repair plan/workflow contract and affected FR-09/15a/18 requirements before implementation |
| Evaluate Jido/Jido.Harness/ACP before building a custom harness bridge | [Jido / Jido.Harness evaluation](design/JIDO-HARNESS.md), then [Pi harness design](design/PI-HARNESS.md), [Observability](archive/OBSERVABILITY.md) and the same FR-09/15a/18 gates |
| Inspect the FR-15aA host/provisioning specification and executable inventory | [FR-15aA provisioning specification](archive/fr-15a/provisioning-specification.md) and its [machine-readable manifest](archive/fr-15a/provisioning-manifest.exs), archived with its validator and test on 2026-09-23 when they left the gate ([why](archive/fr-15a/README.md)); then the governing FR-15aB/FR-09 criteria. The specification enables no execution |
| Inspect the frozen FR-18A observation/query candidate | [FR-18A candidate and evidence](archive/fr-18a/candidate.md), its [independent BLOCKER review](archive/fr-18a/independent-review.md), [narrow correction rereview](archive/fr-18a/correction-rereview.md), [final residual-B1 PASS](archive/fr-18a/final-b1-rereview.md), the [bounded effect-query design](design/bounded-effect-query-design.md), [B5 implementation candidate](archive/fr-18a/bounded-effect-query-candidate.md) [independent B5 BLOCKER review](archive/fr-18a/b5-review.md) and the [B5 correction rereview PASS](archive/fr-18a/b5-correction-rereview.md), then the governing FR-18A criteria and accepted FR-08A combined review; FR-18A remains blocked and this candidate enables no producer, activation or deployment |
| Resume active repairs | [Repair plan](REPAIR-PLAN.md), the current ticket's acceptance criteria and its referenced evidence |
| Judge how far the supervised dogfood alpha is, or pick parallel work that shortens it | [Dogfood readiness](DOGFOOD-READINESS-2026-09-23.md) — requirements, live path, a thin manual lane and its accepted risks, ranked parallel work; proposal at `33395c92`, not approved |
| Implement FR-08B after its atomic prerequisite | [Command-ingress inventory and acceptance matrix](fr-08/fr08b-ingress-inventory.md), then the [atomic-composition diagnosis](fr-08/atomic-composition-diagnosis.md) and governing repair-plan section |
| Resolve FR-08B protected-result/domain binding | [Root-fact composition diagnosis](fr-08/fr08b-root-fact-composition-diagnosis.md), a proposed bounded interface correction with exact inspected revisions, then the [plan-binding implementation specification](fr-08/plan-binding-specification.md), the [replay revalidation design](fr-08/plan-replay-revalidation-design.md), its [frozen partial candidate](fr-08/plan-binding-candidate.md) and the [durable event vocabulary design](fr-08/event-vocabulary-design.md); the binding is integrated (FR-08A complete, per the repair plan; status 2026-09-22) and these are its design record; none enables any execution |
| Understand current alignment, known source gaps and the FR-07→FR-08 disposition | [Independent alignment audit](archive/ALIGNMENT-AUDIT-2026-09-19.md), then [repair plan](REPAIR-PLAN.md) and [FR-08 investigation](fr-08/investigation.md) |
| Inspect the exact disposition candidate and its independent verdict | [Candidate record](archive/alignment-disposition-2026-09-19.md) and [Astra-high PASS](archive/alignment-disposition-review-2026-09-19.md) |
| Inspect the H0 accepted-FR-07 boundary candidate and review | [H0 candidate](fr-08/h0-boundary-candidate.md) and [independent blocker review](fr-08/h0-boundary-review.md) |
| Understand execution authority | [Workflow contract](WORKFLOW-CONTRACT.md), then the applicable repair boundary |
| Check R5 budget-ledger conservation or see its known violations | [Quint model of the R5 ledger](../spec/ledger/README.md): invariants, bounds, three code findings and the unfinished red control |
| Review the frozen FR-08A atomic-composition correction | [Settlement-presence correction narrow PASS](fr-08/atomic-composition-presence-review.md), [prior presence BLOCKER](fr-08/atomic-composition-final-rereview.md), [earlier rereview](fr-08/atomic-composition-rereview.md) and [first review](fr-08/atomic-composition-review.md), each with exact candidate scope |
| Act on the positioning documentation merged in PRs #43–#46 | [Positioning audit](archive/POSITIONING-AUDIT-2026-09-21.md) — fourteen obligations and eleven proposed edits against `d3e37183`, none applied; read it before extending `ORCHESTRATOR-BOUNDARY.md`, `CLOUDFLARE-OS.md`, `ECOSYSTEM-BOUNDARY.md`, `AX-SUBSTRATE.md` or `PLANNING-STRATEGIES.md` |
| Understand future project/role portability | [Project workflow profiles](design/PROJECT-WORKFLOW-PROFILES.md), then the strategy and validation plan |
| Understand replaceable planning strategies, PM/Shaper responsibility, human work projections and workflow experiments | [Planning strategies](design/PLANNING-STRATEGIES.md), then [Project workflow profiles](design/PROJECT-WORKFLOW-PROFILES.md), [Observability](archive/OBSERVABILITY.md) and the governing strategy |
| Understand why repairs exist | [Architecture/lifecycle audit](archive/AUDIT-2026-09-12.md) and its dated verification records |
| Inspect the durable store's actual tables, columns and constraints | [Generated schema reference](DURABLE-STORE-SCHEMA.md); it is generated from `database.ex` and a test fails if the two disagree, so prefer it over reading the schema by hand |
| Build or run model-free checks | [Independent CI](CI.md) and `ci/run.exs` |
| Review or resume FR-08B subcommit 1 (the pure kernel) | [Row-driven coverage design](fr-08/fr08b-row-driven-coverage.md) and [evidence tools](EVIDENCE-TOOLS.md), then the review record in order: [first findings](fr-08/fr08b-subcommit1-review-findings.md), [correction design](fr-08/fr08b-subcommit1-correction-design.md), [re-review briefing](fr-08/fr08b-subcommit1-rereview-briefing.md), [third briefing](fr-08/fr08b-subcommit1-review3-briefing.md), [fourth briefing](fr-08/fr08b-subcommit1-review4-briefing.md), [fourth findings](fr-08/fr08b-subcommit1-review4-findings.md) and the [second fourth-pass review of the evidence architecture](fr-08/fr08b-subcommit1-review4-sol-findings.md), then the [in-flight integration predicate briefing](fr-08/fr08b-integration-issued-review-briefing.md). Four independent reviews, four BLOCKs; the briefings carry what each one changed, and the two fourth-pass reviewers agreed on four things without seeing each other's work |
| Prepare FR-08B subcommit 2 (`decide/3` for the developer role) | [Reads inventory](fr-08/fr08b-subcommit2-reads-inventory.md) and [control/allocation inventory](fr-08/fr08b-subcommit2-control-inventory.md); both are bounded read-only inventories written before the interface froze, so confirm them against the current kernel before coding |
| Prepare FR-08B B3 (R4a control crossing), or check which control/role cells the kernel implements | [B3 gap inventory](fr-08/FR08B-B3-GAP-INVENTORY-2026-09-22.md) — roles × pause/drain/cancel/generation/limit/allocation/ordering with a verdict and test per cell, settlement-binding gaps, contract-reading questions and a correctness-versus-controller split; inventory only, taken at `3727f2e8`, changes nothing |
| Decide the B3 inventory's contract-reading questions Q1–Q7, or see what B3 must contain under each reading | [B3 contract readings proposal](fr-08/FR08B-B3-CONTRACT-READINGS-PROPOSAL-2026-09-22.md) — competing readings with quoted contract text, a recommendation, the cells each reading moves and a minimal correctness-owned B3 scope; proposal, not approved, contract unchanged, taken at `bc62a3b4` |
| Add or change a guard, transition, or a test that asserts a refusal | [Evidence tools](EVIDENCE-TOOLS.md); the gate enforces four of the five checks automatically, the guard mutation sweep is manual, and a green gate after adding a guard is not evidence the guard works |
| Run a script in `bin/`, or decide which belong in the gate | [Bin script health check](archive/BIN-SCRIPT-HEALTH-2026-09-22.md) — what each one claims, how to run it, who calls it, and its result at `6bc015ed`; none of `foundry/bin/` is in `ci/run.exs` |
| Observe the local system | [Observability](archive/OBSERVABILITY.md), with the README's containment warnings |
| Understand historical architecture choices | [Migration design](archive/MIGRATION.md), [migration tickets](archive/MIGRATION-TICKETS.md), [event sourcing](archive/EVENT_SOURCING.md) |
| Plan FR-23 documentation retirement, or decide whether a Foundry document is evidence, current, superseded or retirable | [Documentation retirement inventory](archive/DOC-RETIREMENT-INVENTORY-2026-09-22.md) — a classification of every file at `e374322b`, with grep evidence; it retired nothing and applied no banner |
| Plan FR-23 dead-surface removal, or check whether a `lib/` identifier still dispatches | [Dead surface inventory](archive/DEAD-SURFACE-INVENTORY-2026-09-22.md) — unused functions, list-literal members and modules at `6bc015ed`, each with its recorded search and owner; it removed nothing |
| Decide whether to split FR-23, or pick up FR-23 hygiene before FR-10/11/12/19B land | [FR-23 split proposal](fr-23/FR-23-SPLIT-PROPOSAL-2026-09-22.md) — a proposal at `b46d3825`, not yet approved: FR-23a (hygiene, gated by which files it may touch) and FR-23b (decomposition and retirement, keeping FR-23's dependencies); the repair plan still governs |
| Inspect implementation history | [Implementation log](archive/IMPLEMENTATION-LOG.md); use its reading route and active-ticket headings rather than preloading the append-only history |
| Review an agent assignment | The lane's [work packet and review steps](batch-d/LANE-RUNBOOK.md), the [agent brief](AGENT-BRIEF.md) and the current workflow contract; the legacy `roles/` prompt templates were deleted with the daemon on 2026-09-23 |
| Rebuild a capability the legacy daemon had (launch, prompt delivery, checks, cleanup, scheduling, correction budgets) | [Moved knowledge](design/MOVED-KNOWLEDGE-2026-09-23.md): each edge case the deleted tests encoded, the test name and which of FR-09–FR-13 owns it |

**The active repair plan, not the original eight-ticket migration sequence, owns
repair ordering.** A design-review approval applies to its named candidate; it is not
an endorsement of later revisions or evidence that a protected route is activated.
The plan contains 24 ticket nodes (FR-01–FR-23 plus FR-15a). FR-23 is a ticket covering
legacy retirement, module decomposition and hygiene; F23/F24 are audit findings routed to
existing owners. The `F` and `FR` prefixes distinguish findings from tickets. Its H0/F checkpoints and A/B slices do not form
a competing backlog.

## Provider and backend boundary

Shared repository instructions live in [AGENTS.md](../AGENTS.md). They apply to
Claude, Gemini, DeepSeek, Codex and other providers. That neutrality does not relax
Foundry's launch policy, billing authorization, review identity or backend conformance.
Foundry launches no agent: the Herdr adapter and the daemon that drove it were deleted on
2026-09-23 ([plan amendment C1](REPAIR-PLAN.md#clean-room-amendment)), and the manual lane is
the only ingress. Any future harness adapter passes FR-09 before it runs anything.

## Evidence and navigation

**Records from before the 2026-09-23 split.** Foundry was `foundry/` inside Pramāṇa until
2026-09-23. Older records write paths as `foundry/X` (read `X` at this repository's root) and
cite Pramāṇa commits, which resolve only in
[lorecrafting/pramana](https://github.com/lorecrafting/pramana); the two that tests read are
tagged here as `pramana/<sha>`. Those records are evidence and are not rewritten.

Dated audit, review, integration and attestation files are preserved as evidence, not
rewritten into one current narrative. Use [the complete documentation catalog](https://github.com/lorecrafting/pramana/blob/e1e4b3bf2c666f5d84652758afee446a0b21ebe1/docs/CATALOG.md)
to find an individual record. One historical audit link points to a now-removed legacy
Python diagnostic; [the documentation audit](https://github.com/lorecrafting/pramana/blob/e1e4b3bf2c666f5d84652758afee446a0b21ebe1/docs/audits/2026-09-15/README.md)
records that exception without rewriting the original evidence.

For current status, distinguish inspected source/containment from deployment truth. The
alignment audit did not inspect the loaded release; historical “live” statements and
component inventories therefore do not establish current wiring, activation or provider
execution. The [workflow contract's current-status route](WORKFLOW-CONTRACT.md) preserves
its dated design evidence while directing implementation to H0 and FR-08A/B.

[Repository map](https://github.com/lorecrafting/pramana/blob/e1e4b3bf2c666f5d84652758afee446a0b21ebe1/docs/REPO_MAP.md) · [Shared workflow](https://github.com/lorecrafting/pramana/blob/e1e4b3bf2c666f5d84652758afee446a0b21ebe1/docs/agents/WORKFLOW.md)
