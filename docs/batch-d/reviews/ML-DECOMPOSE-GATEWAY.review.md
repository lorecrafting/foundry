# ML-DECOMPOSE-GATEWAY independent review

Verdict: **approved**

Candidate: `0a8db0b6da471bc586a891546bfa1c4eafeb1ec0`  
Base: `3e27ec02054fff0ca72c22057e6a0837a61f0576`  
Reviewer: `agent:codex-gpt-6-astra/review-ML-DECOMPOSE-GATEWAY`

## Findings, ranked

1. **Low, non-blocking — stale arity in an updated live citation.** `docs/WORKFLOW-CONTRACT.md:195` now points to the correct `domain_commit.ex` but still says `check_expected_revisions/4`. The implementation is `/3` (`domain_commit.ex:470`). The base already implemented `/3` (`gateway.ex:1812`), so this is inherited documentation drift, not a behavioral regression. Change the citation to `/3` when next updating the contract.

No correctness or scope correction required.

## Evidence and attack surface

- Verified the detached review checkout was clean at the exact candidate; all six changed paths fit the packet. No pins, report artifacts, ProtectedPrimitives or checker implementation changed.
- Built base and M3 independently in reviewer-owned detached worktrees with `MIX_DEPS_PATH=/Users/raymondluong/dev/foundry/deps MIX_ENV=test mix compile --warnings-as-errors`, and compiled the final candidate the same way. All three passed: 55/57/57 project source files.
- Ran `bin/check_move.exs` on the independently built base and M3 beams, declaring only `Gateway.atomic_domain_request/1` and `Gateway.domain_read_namespaces/0`. Passed: base Gateway 126 + Maintenance 4 definitions; M3 Gateway 29 + Maintenance 25 + DomainCommit 36 + AtomicBundle 42. These 132 definitions equal the 130 base definitions plus the two exact forwarding delegates. This covers compiler-expanded aliases, constants and default-generated arities. In particular DomainCommit retains the DurableStore.Kernel alias, accepted commit arities 7/8 and rejected commit arities 6/7.
- Reviewed the new public surfaces and call targets against the approved family split. Compiler xref reports DomainCommit callers only Gateway and AtomicBundle, and Maintenance/AtomicBundle callers only Gateway. Gateway retains owner acquisition/release, path revalidation, capability equality, authority-mode routing, recovery state, command-read fencing and health-process bookkeeping. The ProtectedPrimitives back-edge remains through the exact Gateway delegate.
- Inspected the transaction/idempotency/fault flow: DomainCommit owns one transaction; AtomicBundle owns the acceptance transaction and the separate rejection transaction after rollback. Shared domain commit functions open none. Checked caller forwarding, bundle-v2 durable ownership, CAS, post-write Authority reads, reply ordering, idempotency lookup and refusal wrapping against the base.
- Literal comparison across the complete split: transactions 3 → 3, halts 3 → 3, command/atomic digest domains 1/1 each, input prefix 2 → 2, atomic derived-ID prefix 1 → 1, both owner-kind literals 1 → 1, refusal-prefix sets identical (61). No additional T3 semantic deletion: the admitted base already lacks the three legacy protected insert functions and uses the reduced arities. The split preserves that base rather than deleting additional behavior.

## T1, reviewed independently of the pure-move checker

The final base-to-tip checker intentionally fails with `ambiguous split call` for the four changed callable bodies (`checkpoint_database/2`, `last_sequence/1`, `read_operational_health/1`, `verify_backup/3`). This is not recorded as a passing pure move.

Read the entire T1 diff and Maintenance implementation. The three sequence callers use the new private `sequence_query/1` with exactly the former SQL and result shape; their surrounding pattern matches and error branches are unchanged. `last_sequence/1` still wraps SQL errors once; health/checkpoint retain their former handling. `verify_backup/3` calls the existing replay helper, which produces the same map, count and SHA-256 over `term_to_binary(state, [:deterministic])` as the removed `publication_reconstruction/1`; publication checks and sync ordering remain intact. Those four edits, the deleted reconstruction definition, and the new sequence definition are the complete T1 delta.

Ran `/private/tmp/ML-DECOMPOSE-GATEWAY-t1-probe.exs` against the candidate: empty and one-event stores returned literal expected sequences 0/1 through health, checkpoint and offline verification; backup and offline replay matched independently specified reconstruction maps and SHA-256 values; an in-memory SQLite connection without events returned the expected storage-unavailable SQL refusal. Passed. The probe and its temporary stores are outside the repository; stores are cleaned up.

## Checks and limits

- Focused ExUnit command (with `TMPDIR=/private/tmp MIX_ENV=test` and shared deps): `mix test test/foundry/durable_store/operational_storage_test.exs test/foundry/durable_store/fr08a_fr19a_integration_test.exs test/foundry/durable_store/gateway_test.exs test/foundry/durable_store/atomic_bundle_test.exs test/foundry/durable_store/domain_read_check_test.exs test/foundry/durable_store/reopen_property_test.exs test/foundry/architecture_boundary_test.exs` — **103 passed, 0 failed**, 74.7 seconds. This exercises backup/checkpoint failures, process interruption, recovery, atomic refusal/idempotency, domain reads and reopen behavior. The relational-oracle footer reports zero accepted transitions and is vacuous; no oracle coverage claimed from it.
- `mix format --check-formatted` — passed.
- `elixir bin/check_docs.exs` — 0 broken links; AGENTS.md 481/800 words. The two relocated enforcement paths and domain-read test comment point to their owning modules; the low arity finding above remains.
- No new production guard or repository test was added, so no new guard mutation is claimed. Existing pure-move checker was not modified.
- No full gate, FR-08A rebind, provider session or CI run. Operator must add the three approved pins and rebind on the integrated tip. This approval does not claim FR-08A readiness or integration acceptance.

## Ponytail Review

Lean already. Ship. The existing Maintenance module and helpers are reused, the two new modules follow the approved protocol families, and no dependency or speculative framework was added. No deletion proposed within this ticket's scope.
