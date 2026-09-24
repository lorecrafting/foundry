approved

# ML-LANE-FRICTIONS review — agent:claude-fable-5-1/review-ML-LANE-FRICTIONS

Candidate fd208d104236c28472ec1b943975b1a9ee014770 (4 commits) on base
5fb760397f6f755c0bff137d96bbb88167b5d4b3. Reviewed in the detached worktree
/private/tmp/review-ML-LANE-FRICTIONS. The running lane daemon and
~/.local/state/foundry-lane were not touched.

## Scope
`git diff --stat 5fb7603 HEAD`: bin/pramana (usage line), docs/batch-d/LANE-RUNBOOK.md,
lib/foundry/manual_lane/cli.ex, lib/foundry/manual_lane/log.ex,
test/foundry/manual_lane/cli_test.exs. Nothing under
lib/foundry/durable_store or lib/foundry/workflow. All within the packet's
scope list.

## Checks run
- `TMPDIR=/private/tmp MIX_ENV=test MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps mix test
  test/foundry/manual_lane test/foundry/cli test/foundry/rpc_wrapper_test.exs`
  in the review worktree: 85 passed, 0 failures, exit 0.
- Two throwaway `--sname` nodes (no daemon): `--rpc-eval` running `Logger.info("x")` printed
  `[info] x` on the CLIENT's stdout, after the result line; the same with
  `gl: Process.whereis(:user)` printed it on the served node only. A `raise` after
  `IO.write` left stdout as the single object and put the exception on stderr, exit 1.
- Scratch git repo, correction chain base->c1->c2 (candidate 1)->c3 (candidate 2), with only
  c3 cherry-picked onto main: `git cherry -v main c3 base` gave `+ c1`, `+ c2`, `- c3`.
- `git rev-parse --verify --quiet "<x>^{commit}"` for x in `--output=/tmp/x`, `--git-dir`,
  `-q`, `--sq-quote`, `--prefix=foo`, `--flags`, `--parseopt`, `--show-toplevel`, `--`, `-`:
  every one exits 1 with empty output.
- No red-control edits were made; the worktree is unchanged.

## F1 — daemon_log (cli.ex:562)
Correct and safe. OTP forwards a log event whose `gl` metadata is on another node to that
node; under the release `rpc` that is the client. Pinning `gl` to this node's `:user`
keeps the two lane lines (`started`, `finished`) on the daemon. Both run on every path,
refusals included (`observe/4` runs before the `case` that prints and raises). `Logger.info`
does not raise; `Process.whereis(:user) || Process.group_leader()` cannot crash and only
falls back to the old behaviour if `:user` is absent, which it never is in a release. The
only other Logger calls in the lane path (server.ex:84,126) run in the Server process, on
its own group leader; `Log.operator/2` warns with `IO.puts(:stderr, ...)`, the daemon's
stderr. `--json` stays one object: the refusal JSON goes to stdout, the raise to stderr.

The test at cli_test.exs:184 proves the metadata (`meta.gl == Process.whereis(:user)`)
through a handler, not the transport: it does not itself show a client's stdout is clean.
The mechanism is OTP's, and my two-node reproduction above confirms the fix end to end.
Acceptable as the regression guard; note that the repro showed the leaked line arriving
AFTER the result, so before this fix a `--json` consumer could see trailing junk.

## F5 — Log.archive_notes/2
- Path: `<dirname store>/notes/<sha256>.md`; the digest is computed by the code from the
  body, so nothing operator-supplied reaches the path (no traversal). The store-directory
  scans in durable_store (owner.ex:97, path_identity.ex:37,63) only consider
  `*.owner.unclean.recovered.*` names, so `notes/` and `*.tmp` are ignored.
- Rerun with the same notes: same digest, tmp written and renamed over an identical file,
  read back and verified; idempotent.
- Rerun with different notes on a committed review: a second file is archived, then
  `Backend.review` takes its `committed?` path and skips `deliver`, so the receipt keeps
  the first digest, as the runbook (Idempotency paragraph) says. The second file is an
  orphan. Likewise any refused `review` (wrong principal, mismatched candidate, ...) has
  already archived its notes: harmless, content-addressed, never a store write, but the
  directory accumulates. Minor; mention in the runbook or leave.
- Size: the whole notes file is read into memory (pre-existing `read_notes/1`) and now
  written once; unbounded only by the operator's file, same as before. Permissions: default
  umask, like operator.log.jsonl.
- `lane log`: `Log.notes/2` returns the body only if its digest matches; tampered files
  show `body: nil` / "not archived" in text. Tested.
- Refusal `notes_archive_failed` fires before `Backend.review`; tested with a file in place
  of the notes dir, and the claim stays open.

## F6/F10 — lane integrated ID [--ref REF]
- Range: `git cherry -v REF CANDIDATE BASE` is `BASE..CANDIDATE` against REF, so a
  correction candidate that descends from an earlier one is checked over the full chain,
  not just the latest attempt's commits (verified above). `commits` is
  `rev-list --count base..candidate`.
- Candidate: active attempt's, else the latest prior attempt's (prior_attempt_ids is
  appended in commit order, dispositions.ex:38, so `Enum.reverse` picks the newest).
- Injection: ID never reaches git. `--ref` goes only through the pre-existing `rev_parse/2`
  with `^{commit}` appended; every dash-prefixed value tried is refused as
  `git_ref_unresolved`, and `git cherry` receives the resolved SHA. CANDIDATE is a 40-hex
  SHA validated by GitEvidence at submit; BASE came from `rev-parse` at admit.
- Read-only: rev-parse, cherry, rev-list only; no Backend call that writes. The test
  asserts the ticket's events are unchanged. It appends one operator.log.jsonl line like
  `status` and `log`.
- Repo: `ctx.repo`, i.e. FOUNDRY_MANUAL_LANE_REPO, the same repo `admit` resolves in.
- Not available while the Gateway is in recovery (`context/1` admits only `log` then).
  Read-only, so it could be; not claimed anywhere, so not a defect.

## Runbook
Matches the code: the `integrated` command and its output fields, `no_candidate`,
`git_failed`, `notes_archive_failed` (path `state/manual-lane/notes/` matches
`Server.store_path/1`), the integrate step's full-range cherry-pick, and the reviewer's own
detached worktree. Nit: the `git_ref_unresolved` row still reads "`admit --base-ref` does
not resolve"; `integrated --ref` returns the same atom.

## Deferred / nits (none blocking)
1. `git_ref_unresolved` row: add `integrated --ref`.
2. Orphan notes archives on a refused or re-notes'd review; doc it or accept.
3. `integrated` refused in recovery although read-only.
