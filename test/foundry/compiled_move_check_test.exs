defmodule Foundry.CompiledMoveCheckTest do
  use ExUnit.Case, async: true

  test "an altered compiled body fails although the name and arity still match" do
    root = Path.join(System.tmp_dir!(), "compiled_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    compile(base, "Before", "String.upcase(v)")
    compile(candidate, "After", "String.upcase(v)")
    assert {output, 0} = check(base, candidate)
    assert output =~ "compiled definitions match"

    compile(candidate, "After", "String.downcase(v)")
    {output, status} = check(base, candidate)
    assert status != 0
    assert output =~ "compiled definitions differ"

    compile(candidate, "After", "String.upcase(v)")
    source = Path.join(root, "bad_alias.ex")
    File.write!(source, "defmodule BadAlias do\n  alias Foundry.ManualLane.Replay\nend\n")

    {output, status} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "MoveCheck.Before",
          "MoveCheck.After",
          "--lint-protected",
          source
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "forbidden split directive"
  end

  test "a split call to a different same-named implementation is refused" do
    root = Path.join(System.tmp_dir!(), "ambiguous_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    compile_source(
      base,
      "base.ex",
      "defmodule Check.C do\n  def helper, do: :wrong\nend\ndefmodule Check.A do\n  def entry, do: helper()\n  def helper, do: :good\nend\n"
    )

    compile_source(
      candidate,
      "candidate.ex",
      "defmodule Check.C do\n  def helper, do: :wrong\nend\ndefmodule Check.B do\n  def entry, do: Check.C.helper()\n  def helper, do: :good\nend\n"
    )

    {output, status} =
      System.cmd(
        "elixir",
        ["bin/check_move.exs", base, candidate, "Check.A,Check.C", "Check.B,Check.C"],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "ambiguous split call"

    compile_source(base, "empty.ex", "defmodule Check.Empty do\nend\n")
    compile_source(candidate, "added.ex", "defmodule Check.Added do\n  def added, do: :ok\nend\n")

    {output, status} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "Check.Empty",
          "Check.Added",
          "Check.Added.added/0",
          "Check.Added.added/0"
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "duplicate addition"

    compile_source(base, "facade.ex", "defmodule Check.Facade do\n  def value, do: :good\nend\n")

    compile_source(
      candidate,
      "facade.ex",
      "defmodule Check.Owner do\n  def value, do: :good\nend\ndefmodule Check.Facade do\n  defdelegate value(), to: Check.Owner\nend\n"
    )

    {output, 0} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "Check.Facade",
          "Check.Facade,Check.Owner",
          "Check.Facade.value/0"
        ],
        stderr_to_stdout: true
      )

    assert output =~ "compiled definitions match"

    compile_source(
      candidate,
      "facade.ex",
      "defmodule Check.Wrong do\n  def value, do: :wrong\nend\ndefmodule Check.Facade do\n  defdelegate value(), to: Check.Wrong\nend\n"
    )

    {output, status} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "Check.Facade",
          "Check.Facade,Check.Owner,Check.Wrong",
          "Check.Facade.value/0"
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "declared delegate target differs"
  end

  test "line shifts preserve compiled bodies" do
    root = Path.join(System.tmp_dir!(), "line_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    compile_source(base, "value.ex", "defmodule Lines.Before do\n  def value(v), do: v\nend\n")

    compile_source(
      candidate,
      "value.ex",
      "defmodule Lines.After do\n  # moved\n  def value(v), do: v\nend\n"
    )

    {output, 0} =
      System.cmd("elixir", ["bin/check_move.exs", base, candidate, "Lines.Before", "Lines.After"],
        stderr_to_stdout: true
      )

    assert output =~ "compiled definitions match"
  end

  test "a declared facade must forward unchanged to its own moved body" do
    root = Path.join(System.tmp_dir!(), "facade_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    compile_source(
      base,
      "base.ex",
      "defmodule Identity.Facade do\n  def value(a, b), do: a - b\nend\ndefmodule Identity.Other do\n  def value(a, b), do: b - a\nend\n"
    )

    modules = "Identity.Facade,Identity.Other,Identity.Owner"

    args = [
      "bin/check_move.exs",
      base,
      candidate,
      "Identity.Facade,Identity.Other",
      modules,
      "Identity.Facade.value/2"
    ]

    for {facade, accepted?} <- [
          {"defdelegate value(a, b), to: Identity.Owner", true},
          {"defdelegate value(a, b), to: Identity.Other", false},
          {"def value(a, b), do: Identity.Owner.value(b, a)", false},
          {"def value(a, b), do: -Identity.Owner.value(a, b)", false},
          {"def value(a, b) do\n    Identity.Owner.value(a, b)\n    :wrong\n  end", false}
        ] do
      compile_source(
        candidate,
        "candidate.ex",
        "defmodule Identity.Other do\n  def value(a, b), do: b - a\nend\ndefmodule Identity.Owner do\n  def value(a, b), do: a - b\nend\ndefmodule Identity.Facade do\n  #{facade}\nend\n"
      )

      {output, status} = System.cmd("elixir", args, stderr_to_stdout: true)
      assert status == 0 == accepted?, output
    end
  end

  test "protected lint permits narrow imports but rejects unrelated imports" do
    root = Path.join(System.tmp_dir!(), "import_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)
    compile_source(base, "value.ex", "defmodule Imports.Before do\n  def value(v), do: v\nend\n")

    compile_source(
      candidate,
      "value.ex",
      "defmodule Imports.After do\n  def value(v), do: v\nend\n"
    )

    source = Path.join(root, "lint.ex")

    args = [
      "bin/check_move.exs",
      base,
      candidate,
      "Imports.Before",
      "Imports.After",
      "--lint-protected",
      source
    ]

    File.write!(
      source,
      "defmodule Imports.Lint do\n  import Foundry.DurableStore.Protected.Rows, only: [row: 1]\nend\n"
    )

    {output, 0} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert output =~ "compiled definitions match"

    File.write!(
      source,
      "defmodule Imports.Lint do\n  import Foundry.ManualLane.Replay, only: [row: 1]\nend\n"
    )

    {output, status} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert status != 0
    assert output =~ "forbidden split directive"
  end

  defp compile(dir, module, body) do
    compile_source(
      dir,
      "#{module}.ex",
      "defmodule MoveCheck.#{module} do\n  # Line positions differ across revisions.\n  def change(v), do: #{body}\nend\n"
    )
  end

  defp compile_source(dir, file, body) do
    source = Path.join(dir, file)
    File.write!(source, body)
    {output, status} = System.cmd("elixirc", ["-o", dir, source], stderr_to_stdout: true)
    assert status == 0, output
  end

  defp check(base, candidate) do
    System.cmd(
      "elixir",
      ["bin/check_move.exs", base, candidate, "MoveCheck.Before", "MoveCheck.After"],
      stderr_to_stdout: true
    )
  end
end
