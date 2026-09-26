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

  test "a moved local capture may become an imported capture, but keeps its target" do
    root = Path.join(System.tmp_dir!(), "capture_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    compile_source(base, "base.ex", """
    defmodule Capture.Before do
      def use(v), do: Enum.map(v, &helper/1)
      def helper(v), do: v + 1
    end
    """)

    compile_source(
      base,
      "wrong.ex",
      "defmodule Capture.Wrong do\n  def helper(v), do: v - 1\nend\n"
    )

    compile_source(candidate, "candidate.ex", """
    defmodule Capture.Owner do
      def helper(v), do: v + 1
    end
    defmodule Capture.Wrong do
      def helper(v), do: v - 1
    end
    defmodule Capture.After do
      import Capture.Owner, only: [helper: 1]
      def use(v), do: Enum.map(v, &helper/1)
    end
    """)

    args = [
      "bin/check_move.exs",
      base,
      candidate,
      "Capture.Before,Capture.Wrong",
      "Capture.After,Capture.Owner,Capture.Wrong"
    ]

    {output, 0} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert output =~ "compiled definitions match"

    compile_source(candidate, "candidate.ex", """
    defmodule Capture.Owner do
      def helper(v), do: v + 1
    end
    defmodule Capture.Wrong do
      def helper(v), do: v - 1
    end
    defmodule Capture.After do
      import Capture.Wrong, only: [helper: 1]
      def use(v), do: Enum.map(v, &helper/1)
    end
    """)

    {output, status} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert status != 0
    assert output =~ "capture target differs"
  end

  test "a moved rescue keeps its behavior despite anonymous variable context" do
    root = Path.join(System.tmp_dir!(), "rescue_move_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    source = fn mod, result ->
      "defmodule #{mod} do\n  def value(v) do\n    _ = length(v)\n    true\n  rescue\n    ArgumentError -> #{result}\n  end\nend\n"
    end

    compile_source(base, "value.ex", source.("Rescue.Before", ":handled"))
    compile_source(candidate, "value.ex", source.("Rescue.After", ":handled"))
    args = ["bin/check_move.exs", base, candidate, "Rescue.Before", "Rescue.After"]
    {output, 0} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert output =~ "compiled definitions match"

    compile_source(candidate, "value.ex", source.("Rescue.After", ":changed"))
    {output, status} = System.cmd("elixir", args, stderr_to_stdout: true)
    assert status != 0
    assert output =~ "compiled definitions differ"
  end

  test "same-body capture changed to a different owner is refused" do
    root = Path.join(System.tmp_dir!(), "capture_owner_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    source = fn target ->
      "defmodule Capture.Entry do\n  def captures, do: &Capture.#{target}.helper/1\nend\n" <>
        "defmodule Capture.One do\n  def helper(v), do: v + 1\nend\n" <>
        "defmodule Capture.Two do\n  def helper(v), do: v + 1\nend\n"
    end

    compile_source(base, "value.ex", source.("One"))
    compile_source(candidate, "value.ex", source.("Two"))

    {output, status} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "Capture.Entry,Capture.One,Capture.Two",
          "Capture.Entry,Capture.One,Capture.Two"
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "capture target differs"
  end

  test "a retained owner's local capture cannot become remote" do
    root = Path.join(System.tmp_dir!(), "capture_kind_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    source = fn first ->
      "defmodule Flavor.Owner do\n" <>
        "  def captures, do: {#{first}, &Flavor.Owner.helper/1}\n" <>
        "  def helper(v), do: v + 1\nend\n"
    end

    compile_source(base, "value.ex", source.("&helper/1"))
    compile_source(candidate, "value.ex", source.("&Flavor.Owner.helper/1"))

    {output, status} =
      System.cmd(
        "elixir",
        ["bin/check_move.exs", base, candidate, "Flavor.Owner", "Flavor.Owner"],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "capture target differs"
  end

  test "moving a capture does not permit changing its retained target's capture kind" do
    root = Path.join(System.tmp_dir!(), "capture_caller_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    compile_source(base, "value.ex", """
    defmodule Retained.A do
      def captures, do: {&helper/1, &Retained.A.helper/1}
      def helper(v), do: v + 1
    end
    """)

    compile_source(candidate, "value.ex", """
    defmodule Retained.A do
      def helper(v), do: v + 1
    end
    defmodule Retained.B do
      def captures, do: {&Retained.A.helper/1, &Retained.A.helper/1}
    end
    """)

    {output, status} =
      System.cmd(
        "elixir",
        ["bin/check_move.exs", base, candidate, "Retained.A", "Retained.A,Retained.B"],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "capture target differs"
  end

  test "unresolved capture targets are refused" do
    root = Path.join(System.tmp_dir!(), "capture_missing_#{:erlang.unique_integer([:positive])}")
    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    source = fn target ->
      "defmodule Missing.Entry do\n  def capture, do: &Missing.#{target}.absent/1\nend\n" <>
        "defmodule Missing.One do\nend\n"
    end

    compile_source(base, "value.ex", source.("One"))
    compile_source(candidate, "value.ex", source.("One"))

    {output, status} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "Missing.Entry,Missing.One",
          "Missing.Entry,Missing.One"
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    assert output =~ "capture target differs"
  end

  test "unchanged duplicate-key captures stay with their owners" do
    root =
      Path.join(System.tmp_dir!(), "capture_duplicates_#{:erlang.unique_integer([:positive])}")

    base = Path.join(root, "base")
    candidate = Path.join(root, "candidate")
    File.mkdir_p!(base)
    File.mkdir_p!(candidate)
    on_exit(fn -> File.rm_rf!(root) end)

    source =
      "defmodule Duplicate.A do\n  def capture, do: &helper/1\n  def helper(v), do: {:a, v}\nend\n" <>
        "defmodule Duplicate.B do\n  def capture, do: &helper/1\n  def helper(v), do: {:b, v}\nend\n"

    compile_source(base, "value.ex", source)
    compile_source(candidate, "value.ex", source)

    {output, 0} =
      System.cmd(
        "elixir",
        [
          "bin/check_move.exs",
          base,
          candidate,
          "Duplicate.A,Duplicate.B",
          "Duplicate.A,Duplicate.B"
        ],
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
          {"def value(0, b), do: Identity.Owner.value(0, b)", false},
          {"def value({a}, b), do: Identity.Owner.value({a}, b)", false},
          {"def value(a, b) when is_integer(a), do: Identity.Owner.value(a, b)", false},
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
