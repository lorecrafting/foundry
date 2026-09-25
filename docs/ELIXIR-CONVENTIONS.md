# Elixir, Mix and ExUnit conventions

[Foundry](../README.md) › [Docs](README.md) › Elixir, Mix and ExUnit conventions

Applies to every Elixir change in Foundry. Read the
[Phoenix Elixir usage rules](conventions/phoenix/elixir.md) first: they apply as written,
except where this page overrides them. That file is vendored verbatim from Phoenix; refresh it
with `elixir bin/sync_phoenix_rules.exs` and review the diff against the overrides below.
Foundry uses no Phoenix, Ecto, HEEx or LiveView, so only the language rules are vendored.
These are conventions, not proof a check passed; the [boundary rules](BOUNDARY-RULES.md)
govern design.

## Overrides of the upstream rules

Carried over at the split from the reviewed adaptation of the same rules (Phoenix v1.8.11).

- **Nested modules.** Prefer one independently maintained module per file, but existing
  nested helper modules are allowed; several modules in a file are not a compilation error.
- **`Task.async_stream/3`.** Give it bounded concurrency and an explicit timeout. Choose
  `timeout: :infinity` only when another justified lifecycle bound exists; it is not the
  default.
- **Dependencies.** Add none without the operator's approval, the date/time parser included.

## Foundry additions

- Run one file with `TMPDIR=/private/tmp MIX_ENV=test mix test test/x_test.exs`. A delegated
  agent never runs the full suite or `ci/run.exs` ([agent brief](AGENT-BRIEF.md)).
- Before each commit: `mix compile --force --warnings-as-errors` and `mix format`.
- **Temporary directories.** Never hardcode `/private/tmp`: it exists only on macOS, and
  107 tests failed on Linux CI on 2026-09-23 because of it. Use
  `if File.dir?("/private/tmp"), do: "/private/tmp", else: System.tmp_dir!()`, which keeps
  the canonical macOS path that tests comparing resolved paths rely on.
- Shell out through `/bin/sh`, not `zsh` or `bash`: CI runs on Ubuntu.
