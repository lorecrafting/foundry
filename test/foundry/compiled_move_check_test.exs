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
        ], stderr_to_stdout: true)

    assert status != 0
    assert output =~ "forbidden split directive"
  end

  defp compile(dir, module, body) do
    source = Path.join(dir, "#{module}.ex")

    File.write!(
      source,
      "defmodule MoveCheck.#{module} do\n  # Line positions differ across revisions.\n  def change(v), do: #{body}\nend\n"
    )

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
