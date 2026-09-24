Code.require_file("../../support/ast_modules.ex", __DIR__)

defmodule Foundry.ManualLane.NonLaunchTest do
  @moduledoc """
  The manual lane launches nothing (THIN-LANE-DESIGN-2026-09-23.md §1): the transitive
  module closure of every file under `lib/foundry/manual_lane/`, plus
  `work_packet.ex`, starts no OS process except a literal `git` read or the store's `df`
  capacity probe, and reaches no launch-effect or launch-policy module.

  Retargeted 2026-09-23 when the daemon stack (Herdr, AgentServer, Coordinator, launch
  effects) was deleted: forbidding those names by module would now pass vacuously, so the
  test forbids what a launch needs instead — a process spawn (`System.cmd/shell`,
  `Port.open`, `:erlang.open_port`, `:os.cmd`) or a launch module.

  References are resolved with the architecture gate's resolver (`test/support/ast_modules.ex`),
  so an alias, a renamed alias, a multi-alias or a module attribute is a reference. The walk
  follows every referenced module defined under `lib/`. Not seen: `apply/3` with a computed
  module or function, and a spawn reached through a module outside `lib/`.
  """
  use ExUnit.Case, async: true

  alias Foundry.Test.AstModules, as: Ast

  # Launch policy and process effects: kept as leaves for FR-09/FR-10, never lane callees.
  @forbidden [Foundry.LaunchEligibility]
  @forbidden_prefixes [~w(Foundry Effects), ~w(Foundry Quota)]
  @spawns [{System, :cmd}, {System, :shell}, {Port, :open}, {:erlang, :open_port}, {:os, :cmd}]
  # The executable is read from `System.find_executable("df")`, so it is not a literal.
  @dynamic_spawn_allowed [Foundry.DurableStore.Capacity]

  test "the manual lane's module closure reaches no launch path" do
    start = Path.wildcard("lib/foundry/manual_lane/**/*.ex")
    assert start != [], "no manual_lane sources found"
    start = start ++ Enum.filter(["lib/foundry/work_packet.ex"], &File.exists?/1)

    assert forbidden(start, Path.wildcard("lib/**/*.ex")) == []
  end

  test "red control: a direct System.cmd of a non-git executable is seen" do
    path = fixture("defmodule Lane.A do\n def f, do: System.cmd(\"omp\", [\"run\"])\nend")
    assert [{Lane.A, {System, :cmd, "omp"}}] = forbidden([path], [path])
  end

  test "red control: Port.open reached through one intermediate module is seen" do
    a = fixture("defmodule Lane.B do\n alias Lane.Mid\n def f, do: Mid.g()\nend")
    mid = fixture("defmodule Lane.Mid do\n def g, do: Port.open({:spawn, \"x\"}, [])\nend")
    assert [{Lane.Mid, {Port, :open, :dynamic}}] = forbidden([a], [a, mid])
  end

  test "red control: a launch-effect module behind a module attribute is seen" do
    path =
      fixture("defmodule Lane.C do\n @g Foundry.Effects.ProcessGroup\n def f, do: @g\nend")

    assert [{Lane.C, Foundry.Effects.ProcessGroup}] = forbidden([path], [path])
  end

  test "red control: a dynamic git executable and an Erlang spawn are seen" do
    path =
      fixture(
        "defmodule Lane.D do\n def f(g), do: System.cmd(g, [])\n def h, do: :os.cmd(~c\"ls\")\nend"
      )

    assert [{Lane.D, {System, :cmd, :dynamic}}, {Lane.D, {:os, :cmd, :dynamic}}] =
             forbidden([path], [path])
  end

  # {referencing module, forbidden module} for everything the closure of `start` reaches,
  # where `universe` is the set of source files whose modules the walk may enter.
  defp forbidden(start, universe) do
    files = for path <- universe, mod <- defined(ast(path)), into: %{}, do: {mod, path}
    walk(Enum.flat_map(start, &defined(ast(&1))), files, MapSet.new(), [])
  end

  defp walk([], _files, _seen, found), do: Enum.uniq(found)

  defp walk([mod | rest], files, seen, found) do
    if MapSet.member?(seen, mod) or not Map.has_key?(files, mod) do
      walk(rest, files, MapSet.put(seen, mod), found)
    else
      quoted = ast(files[mod])
      refs = references(quoted)
      hits = for ref <- refs, bad?(ref), do: {mod, ref}
      spawns = for spawn <- spawns(quoted), not allowed_spawn?(mod, spawn), do: {mod, spawn}
      walk(rest ++ refs, files, MapSet.put(seen, mod), found ++ hits ++ spawns)
    end
  end

  defp bad?(mod) do
    split = Module.split(mod)
    mod in @forbidden or Enum.any?(@forbidden_prefixes, &List.starts_with?(split, &1))
  end

  defp allowed_spawn?(_mod, {System, :cmd, "git"}), do: true
  defp allowed_spawn?(mod, {System, :cmd, :dynamic}), do: mod in @dynamic_spawn_allowed
  defp allowed_spawn?(_mod, _spawn), do: false

  # `{callee, function, executable}` for every process-spawning remote call in the file;
  # the executable is the literal first argument, or `:dynamic`.
  defp spawns(quoted) do
    bindings = Ast.bindings(quoted)

    for {{:., _, [callee, fun]}, _, args} when is_list(args) <- Ast.nodes(quoted),
        mod <- resolve(callee, bindings),
        {mod, fun} in @spawns,
        do: {mod, fun, executable(args)}
  end

  defp executable([name | _]) when is_binary(name), do: name
  defp executable(_args), do: :dynamic

  # Every resolved module reference in the file, by the gate's resolver.
  defp references(quoted) do
    bindings = Ast.bindings(quoted)

    for node <- Ast.nodes(quoted),
        mod <- resolve(node, bindings),
        String.starts_with?(Atom.to_string(mod), "Elixir."),
        uniq: true,
        do: mod
  end

  defp resolve({:__aliases__, _, _} = node, b), do: Ast.resolve(node, b)
  defp resolve({:@, _, [{_, _, nil}]} = node, b), do: Ast.resolve(node, b)
  defp resolve(atom, _) when is_atom(atom), do: [atom]
  defp resolve(_, _), do: []

  # Every module a file defines, nested names concatenated.
  defp defined(quoted), do: defined(quoted, nil)

  defp defined({:defmodule, _, [{:__aliases__, _, segs}, [do: body]]}, parent) do
    mod = Module.concat([parent || Elixir | segs])
    [mod | defined(body, mod)]
  end

  defp defined({_, _, args}, parent) when is_list(args),
    do: Enum.flat_map(args, &defined(&1, parent))

  defp defined(list, parent) when is_list(list), do: Enum.flat_map(list, &defined(&1, parent))
  defp defined({a, b}, parent), do: defined(a, parent) ++ defined(b, parent)
  defp defined(_, _), do: []

  defp ast(path), do: path |> File.read!() |> Code.string_to_quoted!(file: path)

  defp fixture(source) do
    path = Path.join(System.tmp_dir!(), "non_launch_#{:erlang.unique_integer([:positive])}.ex")
    File.write!(path, source <> "\n")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
