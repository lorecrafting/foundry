defmodule Foundry.XrefCheckTest do
  use ExUnit.Case, async: true

  test "the measured graph stays within both ratchets" do
    {output, status} = System.cmd("elixir", ["bin/check_xref.exs"], stderr_to_stdout: true)
    assert status == 0, output
    assert output =~ "xref:"
  end

  test "a third cycle fails at the measured baseline" do
    graph =
      Enum.reduce(1..3, %{}, fn i, acc ->
        acc
        |> Map.put("a#{i}", %{"b#{i}" => "runtime"})
        |> Map.put("b#{i}", %{"a#{i}" => "runtime"})
      end)

    {output, status} = check(graph)
    assert status != 0
    assert output =~ "3/2 cycles"
  end

  test "a new dependency from a protected split module fails" do
    graph = %{
      "lib/foundry/durable_store/protected/rows.ex" => %{
        "lib/foundry/durable_store/gateway.ex" => "runtime"
      }
    }

    {output, status} = check(graph)
    assert status != 0
    assert output =~ "forbidden split edge:"
  end

  test "a thirteenth compile edge fails even without another cycle" do
    graph =
      Enum.into(1..13, %{}, fn i -> {"source#{i}", %{"sink#{i}" => "compile"}} end)

    {output, status} = check(graph)
    assert status != 0
    assert output =~ "13/12 compile edges"
  end

  defp check(graph) do
    path = Path.join(System.tmp_dir!(), "xref_#{:erlang.unique_integer([:positive])}.json")
    File.write!(path, :json.encode(graph))
    on_exit(fn -> File.rm(path) end)
    System.cmd("elixir", ["bin/check_xref.exs", "--graph", path], stderr_to_stdout: true)
  end
end
