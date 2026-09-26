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

    {from, to} =
      files(
        "defmodule MoveFixture.SourceExisting do\n  def value, do: :ok\nend\n",
        "defmodule MoveFixture.TargetExisting do\n  def keep, do: :left\nend\n"
      )

    Mix.Tasks.Foundry.Move.run(["--from", from, "--to", to, "--functions", "value/0"])
    Code.compile_file(to)
    assert apply(MoveFixture.TargetExisting, :value, []) == :ok
  end

  test "refuses stranded callers, captures and alias conflicts before writing" do
    empty = "defmodule MoveFixture.Target do\nend\n"

    cases = [
      {"def call(v), do: shout(v)\n  def shout(v), do: v", empty, ~r/local calls cross/},
      {"def caller, do: &shout/1\n  def shout(v), do: v", empty, ~r/local calls cross/},
      {"def caller(v), do: v |> shout()\n  def shout(v), do: v", empty, ~r/local calls cross/},
      {"def helper(v), do: v\n  def shout(v), do: v |> helper()", empty, ~r/local calls cross/},
      {"alias String, as: Text\n  def shout(v), do: Text.upcase(v)",
       "defmodule MoveFixture.Target do\n  alias List, as: Text\nend\n",
       ~r/alias Text conflicts/},
      {"def shout(v), do: String.upcase(v)",
       "defmodule MoveFixture.Target do\n  alias List, as: String\nend\n",
       ~r/alias String conflicts/},
      {"alias String, as: Text\n  def shout(v), do: Text.upcase(v)",
       "defmodule MoveFixture.Target do\n  alias List, as: String\nend\n",
       ~r/alias String conflicts/},
      {"alias String, as: Text\n  alias Text, as: More\n  def shout(v), do: More.upcase(v)",
       empty, ~r/alias chain/}
    ]

    Enum.each(cases, fn {body, target, reason} ->
      {from, to} = files("defmodule MoveFixture.Source do\n  #{body}\nend\n", target)
      before = {File.read!(from), File.read!(to)}

      assert_raise Mix.Error, reason, fn ->
        Mix.Tasks.Foundry.Move.run(["--from", from, "--to", to, "--functions", "shout/1"])
      end

      assert {File.read!(from), File.read!(to)} == before
    end)
  end

  test "a missing destination directory leaves the source intact" do
    {from, to} = files("defmodule MoveFixture.Source do\n  def hello, do: :ok\nend\n", "")
    missing = Path.join([Path.dirname(to), "missing_parent", "target.ex"])
    before = File.read!(from)

    assert_raise Mix.Error, ~r/destination parent/, fn ->
      Mix.Tasks.Foundry.Move.run([
        "--from",
        from,
        "--to",
        missing,
        "--module",
        "MoveFixture.Target",
        "--functions",
        "hello/0"
      ])
    end

    assert File.read!(from) == before
    refute File.exists?(missing)
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
