defmodule Foundry.OutlineTest do
  use ExUnit.Case, async: true

  test "reports nested modules, guarded functions and macro spans" do
    path =
      fixture(
        "defmodule A do\n  def x(a) when is_atom(a), do: a\n  defmodule B do\n    defmacro m, do: :ok\n  end\nend\n"
      )

    {output, 0} = System.cmd("elixir", ["bin/outline.exs", path], stderr_to_stdout: true)

    assert output ==
             "module A 1-6\ndef A.x/1 2-2\nmodule A.B 3-5\ndefmacro A.B.m/0 4-4\n"
  end

  test "malformed source fails rather than producing a partial outline" do
    path = fixture("defmodule Broken do\n  def x(\n")
    {output, status} = System.cmd("elixir", ["bin/outline.exs", path], stderr_to_stdout: true)
    assert status != 0
    assert output =~ path
  end

  defp fixture(source) do
    path = Path.join(System.tmp_dir!(), "outline_#{:erlang.unique_integer([:positive])}.ex")
    File.write!(path, source)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
