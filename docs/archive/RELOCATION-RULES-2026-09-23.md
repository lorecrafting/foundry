# Relocation rules (retired 2026-09-23)

Recorded 2026-09-23. `PramanaFoundry.Relocation` and `relocation/*` were deleted under
[repair-plan amendment C3](../REPAIR-PLAN.md#clean-room-amendment) (sweep question Q6).
Mutation had been disabled since FR-19A (`relocation_status/0` returned
`{:error, {:relocation_disabled, :fr19b_required}}`), and nothing outside `relocation/`
called it. These are the F21 rules any future offline move tool must meet, with the
deleted tests that encoded each. Test paths are as of `db4334c`.

| Rule | Encoded by (deleted) |
|---|---|
| Offline and explicit: refuse before creating or reading a journal while disabled | `relocation_containment_test.exs` "execute is disabled before creating a journal", "resume and rollback are disabled before reading a journal" |
| Dry-run manifest first: git common-dir, branch, dirty tracked bytes, untracked, ignored, symlinks (broken ones flagged), live handles, collisions, disk use | `relocation/manifest_test.exs` "analyzes full inventory …" |
| Insufficient destination headroom blocks the whole plan | `relocation/manifest_test.exs` "detects insufficient destination headroom" |
| Never move the original checkout or the root chat's working directory; never move onto an existing destination (collision) | `relocation/worktree_test.exs` "refuses to move original checkout", "… root chat working directory", "… destination collides …"; `relocation_test.exs` "plan creates structured plan …" |
| Registered worktrees move with `git worktree move`, leaving the original checkout intact | `relocation/worktree_test.exs` "moves worktree via git worktree move …" |
| Digest every file (lowercase SHA-256, `.git` skipped) before the move and verify byte-for-byte after; report missing and modified files | `relocation/digest_test.exs` (all four) |
| Journal each step (append-only, fsync) before its effect so a crash resumes or rolls back deterministically at every boundary (`after_prepare`, `before_move`, `after_move`, `after_digest_verify`, `after_complete`, `after_path_map`) with no orphaned state | `relocation/journal_test.exs`; `relocation/crash_recovery_test.exs` (skipped until FR-19B) |
| Historical evidence is never rewritten: old paths resolve through a versioned, persisted, chainable map (longest prefix wins, reversible) | `relocation/path_map_test.exs` (all five) |
| Protect the runtime root with a narrow local git exclude, preserving the user's existing exclusions and staging nothing | `relocation/local_exclude_test.exs` (both) |
| Rollback restores the source and verifies its digests | `relocation/worktree_test.exs` "moves and rolls back regular directory" |

## Where the deleted code fell short

The [2026-09-12 audit, F21](AUDIT-2026-09-12.md) found the implementation weaker than
these rules, and that is why it was disabled rather than repaired:

- Live handles were collected as warnings but did not block movability.
- Failed disk-space discovery invented headroom; failed digest collection became an
  empty map, which disabled verification. Unknown safety evidence must block.
- A cross-device move (`File.cp_r` then `File.rm_rf!`) removed the source before the
  copy's digest was verified. Verify the copy before removing the source.
- Journal paths were not validated against a strict schema, some journal and path-map
  write failures were ignored, and journal strings went through `String.to_atom`.
- Rollback did not refuse collisions.
- Cross-device loss was never exercised by a test.
