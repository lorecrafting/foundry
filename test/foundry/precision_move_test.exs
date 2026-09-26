defmodule Foundry.PrecisionMoveTest do
  use ExUnit.Case, async: false

  test "moves a named function and carries its alias into the target" do
    {from, to} =
      files(
        "defmodule MoveFixture.Source do\n  alias String, as: Text\n  def keep, do: :left\n  @doc false\n  def shout(v), do: Text.upcase(v)\nend\n",
        "defmodule MoveFixture.Target do\n  def keep, do: :right\nend\n"
      )

    File.rm!(to)

    Mix.Tasks.Foundry.Move.run([
      "--from",
      from,
      "--to",
      to,
      "--module",
      "MoveFixture.Target",
      "--functions",
      "shout/1"
    ])

    Code.compile_file(from)
    Code.compile_file(to)
    refute function_exported?(MoveFixture.Source, :shout, 1)
    assert apply(MoveFixture.Target, :shout, ["move"]) == "MOVE"
  end

  test "refuses stranded callers, captures and alias conflicts before writing" do
    {from, to} =
      files(
        "defmodule MoveFixture.Source do\n  def call(v), do: shout(v)\n  def shout(v), do: v\nend\n",
        "defmodule MoveFixture.Target do\nend\n"
      )

    before = {File.read!(from), File.read!(to)}

    assert_raise Mix.Error, ~r/local calls cross/, fn ->
      Mix.Tasks.Foundry.Move.run(["--from", from, "--to", to, "--functions", "shout/1"])
    end

    assert {File.read!(from), File.read!(to)} == before

    {from, to} =
      files(
        "defmodule MoveFixture.Source do\n  def caller, do: &shout/1\n  def shout(v), do: v\nend\n",
        "defmodule MoveFixture.Target do\nend\n"
      )

    before = {File.read!(from), File.read!(to)}

    assert_raise Mix.Error, ~r/local calls cross/, fn ->
      Mix.Tasks.Foundry.Move.run(["--from", from, "--to", to, "--functions", "shout/1"])
    end

    assert {File.read!(from), File.read!(to)} == before

    {from, to} =
      files(
        "defmodule MoveFixture.Source do\n  alias String, as: Text\n  def shout(v), do: Text.upcase(v)\nend\n",
        "defmodule MoveFixture.Target do\n  alias List, as: Text\nend\n"
      )

    before = {File.read!(from), File.read!(to)}

    assert_raise Mix.Error, ~r/alias Text conflicts/, fn ->
      Mix.Tasks.Foundry.Move.run(["--from", from, "--to", to, "--functions", "shout/1"])
    end

    assert {File.read!(from), File.read!(to)} == before
  end

  defp files(source, target) do
    dir = Path.join(System.tmp_dir!(), "move_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    from = Path.join(dir, "source.ex")
    to = Path.join(dir, "target.ex")
    File.write!(from, source)
    File.write!(to, target)
    on_exit(fn -> File.rm_rf!(dir) end)
    {from, to}
  end
end
