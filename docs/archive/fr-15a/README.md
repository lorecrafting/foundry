# FR-15aA provisioning evidence (archived 2026-09-23)

**Archived 2026-09-23 under [plan amendment C2](../../REPAIR-PLAN.md#clean-room-amendment).**
These files left the gate on that date. FR-15aA is complete; its subject, the OMP launch
route through the Coordinator, AgentServer, Herdr and the launch effects, was deleted by
amendment C1. Twelve of the manifest's sixteen repository pins named files that deletion
removed, so the validator could only be rebound to a route that no longer exists.

| File | Was at | Role |
|---|---|---|
| `provisioning-manifest.exs` | `docs/fr-15a/` | The provisioning manifest: principals, channels, routes, host profile, sha256 pins |
| `validate_fr15aa.exs` | `ci/` | `Foundry.CI.FR15aAValidator`, the manifest validator |
| `fr15aa_provisioning_test.exs.txt` | `test/foundry/repair/fr15aa_provisioning_test.exs` | The gate test; renamed so it is no longer compiled |
| `independent-review-probes.exs`, `independent-rereview-probes.exs`, `independent-final-review-probes.exs` | `docs/fr-15a/` | The review rounds' mutation probes against the validator |

The files are unchanged apart from the move. Their relative paths (`../../ci/…`,
`../docs/fr-15a/…`) and sha256 pins are as they were at the last gated commit,
`db4334c`; none of them runs from here. To reproduce a result, check out that commit.

The prose record stays in [`docs/fr-15a/`](evidence.md).
