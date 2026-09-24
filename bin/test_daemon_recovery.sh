#!/usr/bin/env bash
# Isolated FR-04 ownership/recovery fixture wrapper. No daemon or Herdr is started.

set -euo pipefail

cd "$(dirname "$0")/.."

# The toolchain's own bin directories, so the restricted PATH below keeps elixir and erl.
TOOL_PATH="$(elixir -e 'IO.puts(Path.dirname(System.find_executable("elixir")) <> ":" <> Path.join(:code.root_dir(), "bin"))')"
FIXTURE_PARENT="$(mktemp -d /tmp/foundry-fr04-recovery.XXXXXX)"

cleanup() {
  rm -rf -- "$FIXTURE_PARENT"
}
trap cleanup EXIT

export PATH="$TOOL_PATH:/usr/bin:/bin"
export TMPDIR="$FIXTURE_PARENT/tmp"
export MIX_ENV=test
mkdir -p "$TMPDIR"
unset HERDR_ENV COORDINATOR_TICK PRAMANA_RUNTIME_ROOT PRAMANA_RUNTIME_ROOT_FRESH

mix test test/pramana_foundry/daemon_recovery_test.exs --seed 40423
