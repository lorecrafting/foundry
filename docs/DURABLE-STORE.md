# Durable workflow store

[Foundry](../README.md) › [Docs](README.md) › Durable workflow store

FR-07 introduced the version-1 SQLite authority boundary. It is the store behind the
[manual lane](batch-d/LANE-RUNBOOK.md): every lane write goes through this gateway, and every
transition through the workflow kernel, and the legacy mutation paths it once contained were deleted with the
daemon stack ([plan amendment C1](REPAIR-PLAN.md#clean-room-amendment)). For the
mechanism in plain terms, read [How Foundry works §4](CONCEPTS.md#4-core-the-durable-authority-store)
first.

## Boundary

`Foundry.DurableStore.Gateway` owns one in-process Exqlite connection in one
GenServer. The dependency is pinned to `exqlite == 0.40.0`; its bundled native SQLite
implementation is the necessary database engine, not a Python service or sidecar.
An independent SQLite lock sidecar and durable unclean-owner marker admit one owner across
BEAM/OS processes. Ambiguous owner loss requires explicit
recovery evidence before redispatch. The authority connection is configured and checked
for WAL, `synchronous=FULL`, foreign keys and schema/application versions before ready.
One strict `PathIdentity` is established before ownership or SQLite. Relative or lexical
alias paths, dot/dotdot components, repeated/trailing separators, symlinks in any parent
or leaf, hardlinks and non-regular database files are refused. The same identity is
revalidated around owner acquisition and database open and is passed through gateway
and backup operations.

The updatable kernel supplies only a versioned, pure-data proposal containing a result,
known domain events, projections and pending effect requests. Exact domain-tagged request
digests bind effect identities and bounded operations. `Kernel.normalize_bundle/1` rejects
SQL, callbacks, protected rows, candidate-issued/terminal status and rejected decisions
that attempt domain mutation. Protected operations (policy, control, ledger, reservation,
effect, claim, receipt, lease) enter only through `Gateway.protected_command/4` and
`Gateway.atomic_bundle/4`, which write the `root_*` tables and require an unforgeable
reference supplied to the gateway at protected startup. It is absent from the
candidate-facing operation and all status/results. FR-15a must prove the separate kernel
process/account cannot inspect the protected BEAM or obtain this capability; an Elixir
reference is an interface capability, not the eventual OS security boundary.

The FR-07 legacy protected route (`transact_verified` with its `ProtectedVerifier`, the only
writer of the `ledger_generations`, `claims` and `reservations` tables) was deleted by
ML-DEAD-ROUTES: it was already refused once a store held a root command, and the lane seeds
its root policy on first start. Those three tables stay in the v1 schema and nothing writes
them. `Authority` still verifies any retained rows at open and on reads, and a store that
holds them with no root command is in legacy authority mode, where `protected_command` and
`atomic_bundle` refuse with `legacy_authority_mode_active`.

The gateway calculates command identity from the authenticated actor and complete
canonical request, checks an existing command ID before current proposal processing, and
commits the input, command, result, events, projections and intents in one
`BEGIN IMMEDIATE` transaction. The reply happens only after checked `COMMIT`. Same actor/ID/digest returns the stored result; a different
actor or request returns an idempotency conflict. Storage errors put the gateway into
visible recovery mode. Constraint-invalid proposals roll back without poisoning an
otherwise valid store.
Valid stale-revision decisions instead durably commit an authenticated rejected
command/result with no events, projections, intents or protected rows. Same-ID retry
returns that immutable rejection.

`RecordCodec` accepts closed vocabularies only: command types are the lane's `enqueue`
ingress and the kernel's `decide/3` commands, event types are exactly the kernel's
lifecycle events, and domain intents name `launch` or `check`. The pre-repair command,
event and intent names and the legacy-import record codecs were deleted with the
fresh-store decision (ML-DEAD-VOCAB).

## Initialization, recovery and versions

Initialization is a separate exclusive operation:

```elixir
:ok = Foundry.DurableStore.Gateway.initialize("/absolute/offline/path.sqlite3")
```

A gateway never creates a missing database. Missing initialization, a malformed SQLite
file, failed WAL/FULL configuration, failed integrity check, unknown SQL `user_version`,
unknown protocol/event/projection metadata, foreign-key violation, sequence gap or
malformed/unknown-version retained body starts in `:recovery` and refuses writes. It does
not replace the file or report empty healthy state. A corrupt result found on a live read
or idempotent retry also fences immediately. `RecordCodec` is the single normalization,
encoding, decoding and relational-binding definition used by admission, materialization,
startup, result reads, backup and reconstruction. It applies only the declared omitted
result-reason and omitted-bundle-collection defaults. Corruption at these boundaries uses
one `authority_corrupt` classification. SQL,
protocol, event and projection versions are recorded
independently; schema creation is transactional. There is no migration path: stores are
fresh-only, and a store whose protected version, migration markers or table set differ
from a fresh initialization refuses at open.

Schema v1 has separate metadata, authenticated inputs, commands/results, ordered events,
projections, effects, claims, receipts, leases, ledger generations/reservations,
policy/control revisions, artifact references and the retired legacy-import tables
(`import_runs`, `legacy_records`), which must stay empty. Foreign keys
bind owners. Unique constraints cover command, event, effect, receipt/request and
outstanding-claim identities. Effect and claim status retain
`pending/claimed/issued/unknown/succeeded/failed/non_started/cancelled` distinctions.
Startup and global reads compare every table, key, foreign key and index—including the
active-claim partial predicate—with a reference contract instantiated from the same
trusted DDL used for initialization; matching object names alone are not accepted.
Projection carriers are stored beside ordered events and indexed by entity. Their values
are checked against canonical event bodies, and live reads stream only the requested
entity through the shared reducer while proving the retained row is its final carrier.

## Retired legacy import

The offline JSONL importer (`LegacyImport`, with `LegacyLine`, `Schema` and `AtomicFile`)
was deleted on 2026-09-23 under [plan amendment C3](REPAIR-PLAN.md#clean-room-amendment):
Foundry stores start fresh and nothing is imported. The `import_runs` and `legacy_records`
tables stay in the v1 schema so existing stores keep their exact schema contract, but they
are now unsupported retained authority: any row in them fences startup like a retained
receipt or lease. The edge cases the importer proved are recorded in
[moved knowledge](design/MOVED-KNOWLEDGE-2026-09-23.md#legacy-import-and-h0-retired).

## Operational health and bounded diagnostics

`Gateway.operational_health/1` reports the last durable event sequence, SQLite database
and WAL bytes, the configured SQLite page ceiling and the physical bytes currently
reported by the fixed `df -Pk` probe. A missing, failed or malformed probe is `unknown`;
it is never converted to invented headroom. The probe is diagnostic and has no authority
to admit work. It runs in an isolated monitored process with a five-second default bound,
so an OS probe exit or stall cannot crash or indefinitely block the store owner.
`Gateway.recent_events/2` returns only event identities/type/sequence in
descending sequence order and requires a limit from 1 through 1,000. It is explicitly a
bounded diagnostic, not an authoritative replay API.

`Gateway.checkpoint/1` serializes a real `wal_checkpoint(TRUNCATE)` call through the sole
gateway owner and compares complete authority content and reconstructed projections before
and after it. Failure fences later mutations. This is operational maintenance, not WAL
retention or compaction policy, which remains FR-19B.

## Backup, offline verification and limitations

`Gateway.backup/2` uses SQLite `VACUUM INTO`, an engine-produced coherent snapshot rather
than copying a live database/WAL pair. The destination must be a new absolute normalized
path. The gateway reopens the snapshot under the same version checks and compares a
stable SHA-256 over complete ordered rows of every authority/import/metadata table.
Projection-changing events and projection writes are bijective and ordered. Multiple
transitions for one entity consume one initial authoritative read and advance exactly one
revision at a time. The same codec reducer is used before commit and during replay, and
the verifier compares reconstructed projection state with the stored projection table,
detecting missing, reordered and same-count body corruption. FR-19 owns retention,
checkpoint/compaction interruption, archival and operational
backup policy.

`Foundry.DurableStore.Maintenance.verify/2` is the offline verification entry
point. It takes the same cross-process owner lock as the gateway, so a live store is
refused. It opens through the normal schema/physical/authority validation, reads complete
ordered content, replays projections through the shared reducer and returns a deterministic
replay digest. It never repairs, replaces, relocates or removes the input. Backup and
checkpoint interruption leaves the original store behind; an unclean owner marker forces
explicit recovery evidence before reopening.

The acceptance suite uses the real pinned binding and exercises an actual SQLite
`max_page_count` FULL failure, an actual read-only filesystem/open failure and a real OS
`RLIMIT_FSIZE` SQLite commit/write error. It also checks that WAL/FULL is active on real
commits. Deterministic failures after each bundle
table test rollback/fencing, and subprocess `System.halt/1` fixtures test process loss
immediately before and after multi-table domain commits over prior committed history.
A test-only loadable extension interposes only the tested connection's WAL
`sqlite3_io_methods`. It observes successful WAL writes, then returns
`SQLITE_IOERR_FSYNC` from the targeted WAL `xSync` during checked COMMIT. Ordinary and
hard-exit fixtures submit complete domain bundles, including input, command, result,
event, projection and effect rows, and prove no success acknowledgment, immediate write fencing, explicit
owner recovery, full-table-content/reconstruction consistency, and ambiguity-safe
same-command retry whether recovery retained the full bundle or none of it. This is
attributed SQLite VFS `xSync` fault evidence through the production
Exqlite connection; it is not a claim that a kernel `fsync(2)` syscall or physical medium
failed. FR-19 retains the broader physical capacity, filesystem sync, WAL/checkpoint and
compaction fault matrix.

FR-19A additionally exercises an actual SQLite WAL checkpoint, a hard VM exit immediately
after checkpoint and immediately after `VACUUM INTO`, and byte-level corruption of a
previously valid SQLite database. These are real engine/file operations with deterministic
process interruption points. The existing `max_page_count` case is an SQLite logical-full
condition, `RLIMIT_FSIZE` is a kernel file-size-limit I/O failure, and the loadable VFS
extension is an injected SQLite `xSync` error. None is physical filesystem ENOSPC, an
observed kernel `fsync(2)` failure, power loss, controller/cache flush proof or media
durability evidence. Those physical guarantees were unavailable on the development host
and are not claimed.

Offline relocation was retired on 2026-09-23 ([plan amendment C3](REPAIR-PLAN.md#clean-room-amendment));
its rules and the tests that encoded them are in
[the archived relocation rules](https://github.com/lorecrafting/foundry/blob/records/2026-09-24/docs/archive/RELOCATION-RULES-2026-09-23.md).
