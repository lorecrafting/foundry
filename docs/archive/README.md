# Archive

Dated evidence: audits, inventories, candidates, reviews, attestations and probes that
recorded a decision or a finding at a named commit, plus the documents that described
mechanisms deleted in batch A1 ([clean-room amendment](../REPAIR-PLAN.md#clean-room-amendment)).
Nothing here describes the current code; the [documentation index](../README.md) routes to
what does. Files keep the path they had under `docs/` (`docs/fr-07/…` is now
`docs/archive/fr-07/…`) and are not rewritten beyond their relative links. **Pre-split
paths:** Foundry was `foundry/` inside Pramāṇa until 2026-09-23, so older records write
`foundry/X` for what is now `X` at this repository's root, and the commit SHAs they cite
resolve only in [lorecrafting/pramana](https://github.com/lorecrafting/pramana) (the two that
tests read survive here as `pramana/<sha>` tags).

## Why the repairs exist

- [Architecture and lifecycle audit, 2026-09-12](AUDIT-2026-09-12.md) and its
  [verification records](audit-2026-09-12/verification.md)
- [Independent alignment audit, 2026-09-19](ALIGNMENT-AUDIT-2026-09-19.md), with the
  [disposition candidate](alignment-disposition-2026-09-19.md) and its
  [review](alignment-disposition-review-2026-09-19.md)
- [Positioning audit, 2026-09-21](POSITIONING-AUDIT-2026-09-21.md)
- [Implementation log](IMPLEMENTATION-LOG.md): the append-only history to 2026-09-23

## Repair tickets, by ticket

Candidates, reviews, review responses and integration attestations.

| Ticket | Record |
|---|---|
| FR-01 no paid execution | [fr-01/](fr-01/integration-attestation.md) |
| FR-02 inert CLI transport | [fr-02/](fr-02/integration-attestation.md) |
| FR-03 fenced startup | [fr-03/](fr-03/integration-attestation.md) |
| FR-04 owned cleanup | [fr-04/](fr-04/integration-attestation.md) (the identity-drift probe stays at `docs/fr-04/`, cited from `process_group.ex`) |
| FR-05 acceptance containment | [fr-05/](fr-05/integration-attestation.md) |
| FR-06 workflow contract decision | [design review](FR-06-DESIGN-REVIEW.md), [v2](FR-06-DESIGN-REVIEW-V2.md), [fr-06/](fr-06/verification.md) |
| FR-07 durable store | [fr-07/](fr-07/candidate.md) |
| FR-09 Pi checkpoint F | [feasibility](fr-09/checkpoint-f-feasibility.md), [review](fr-09/checkpoint-f-review.md), [rereview](fr-09/checkpoint-f-rereview.md) |
| FR-15aA provisioning (validator retired 2026-09-23) | [why archived](fr-15a/README.md), [specification](fr-15a/provisioning-specification.md), [evidence](fr-15a/evidence.md) |
| FR-18A observation queries | [candidate](fr-18a/candidate.md), [B5 candidate](fr-18a/bounded-effect-query-candidate.md); the design is in [design/](../design/bounded-effect-query-design.md) |
| FR-19A storage and recovery | [candidate](fr-19a/candidate.md), [final rereview](fr-19a/final-rereview.md) |
| FR-21 independent CI | [fr-21/](fr-21/integration-attestation.md) |

FR-08's record stays at [`docs/fr-08/`](../fr-08/investigation.md) until its per-file triage.

## Retired mechanisms

- [Event sourcing](EVENT_SOURCING.md): the JSONL event log
- [Migration design](MIGRATION.md) and [migration tickets](MIGRATION-TICKETS.md): the
  daemon cutover and workspace relocation
- [Observability](OBSERVABILITY.md): legacy telemetry, health probe and Improver; its
  OpenTelemetry direction is FR-18 design input ([current page](../OBSERVABILITY.md))
- [Assessor](ASSESSOR.md) and [relocation rules](RELOCATION-RULES-2026-09-23.md)

## Inventories that fed the clean-room sweep

- [Documentation retirement inventory](DOC-RETIREMENT-INVENTORY-2026-09-22.md)
- [Dead surface inventory](DEAD-SURFACE-INVENTORY-2026-09-22.md)
- [Bin script health check](BIN-SCRIPT-HEALTH-2026-09-22.md)
