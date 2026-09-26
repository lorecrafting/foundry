# Measured at c55413fec19b113baa2f463e8dfaeb22674d8f91:
# mix xref graph --format cycles: 2 strongly connected components;
# mix xref graph --label compile --format stats: 12 direct compile edges.
defmodule Foundry.XrefCheck do
  @cycle_limit 2
  @compile_limit 12
  @root "lib/foundry/durable_store/"
  @protected %{
    "protected/rows.ex" => ~w(database.ex encoding.ex),
    "protected/guards.ex" => ~w(protected/rows.ex database.ex encoding.ex),
    "protected/read_set.ex" => ~w(protected/rows.ex database.ex encoding.ex),
    "protected/reads.ex" => ~w(protected/rows.ex database.ex encoding.ex),
    "protected/transition_replay.ex" => ~w(protected/rows.ex database.ex encoding.ex),
    "protected/operations.ex" => ~w(protected/guards.ex protected/rows.ex database.ex encoding.ex),
    "protected/restart_check.ex" => ~w(protected/transition_replay.ex protected/guards.ex protected/rows.ex database.ex encoding.ex transition_plan.ex gateway.ex),
    # Gateway and TransitionPlan are existing edges until the facade is split.
    "protected_primitives.ex" => ~w(protected/rows.ex protected/read_set.ex protected/operations.ex protected/guards.ex protected/reads.ex protected/restart_check.ex database.ex encoding.ex gateway.ex transition_plan.ex)
  }
  @gateway %{
    "domain_commit.ex" => ~w(kernel.ex transition_plan.ex record_codec.ex encoding.ex authority.ex database.ex protected_primitives.ex),
    "atomic_bundle.ex" => ~w(domain_commit.ex transition_plan.ex protected_primitives.ex record_codec.ex encoding.ex authority.ex database.ex),
    "maintenance.ex" => ~w(database.ex authority.ex path_identity.ex encoding.ex owner.ex capacity.ex),
    "gateway.ex" => ~w(atomic_bundle.ex domain_commit.ex maintenance.ex owner.ex path_identity.ex database.ex protected_primitives.ex capacity.ex authority.ex encoding.ex kernel.ex record_codec.ex transition_plan.ex)
  }

  def run(["--graph", path]), do: path |> File.read!() |> :json.decode() |> check()

  def run([]) do
    {json, 0} = System.cmd("mix", ["xref", "graph", "--format", "json", "--output", "-", "--no-compile"], stderr_to_stdout: true)
    json |> :json.decode() |> check()
  end

  def run(_), do: raise("usage: elixir bin/check_xref.exs [--graph FILE]")

  defp check(graph) do
    edges = for {from, targets} <- graph, {to, label} <- targets, do: {from, to, label}
    compile = Enum.count(edges, fn {_, _, label} -> label == "compile" end)
    cycles = cycles(graph)
    forbidden = for {from, to, _} <- edges, edge_forbidden?(from, to), do: {from, to}
    IO.puts("xref: #{cycles}/#{@cycle_limit} cycles, #{compile}/#{@compile_limit} compile edges, #{length(forbidden)} forbidden split edges")

    if cycles > @cycle_limit or compile > @compile_limit or forbidden != [] do
      Enum.each(forbidden, fn {from, to} -> IO.puts(:stderr, "forbidden split edge: #{from} -> #{to}") end)
      System.halt(1)
    end
  end

  defp edge_forbidden?(from, to) do
    with true <- String.starts_with?(from, @root),
         true <- String.starts_with?(to, @root),
         source = String.replace_prefix(from, @root, ""),
         target = String.replace_prefix(to, @root, ""),
         {:ok, allowed} <- Map.fetch(Map.merge(@gateway, @protected), source) do
      target not in allowed
    else
      _ -> false
    end
  end

  defp cycles(graph) do
    g = :digraph.new()
    Enum.each(graph, fn {from, targets} ->
      :digraph.add_vertex(g, from)
      Enum.each(targets, fn {to, _} ->
        :digraph.add_vertex(g, to)
        :digraph.add_edge(g, from, to)
      end)
    end)

    count =
      g
      |> :digraph_utils.strong_components()
      |> Enum.count(fn
        [_] = nodes -> Enum.any?(nodes, fn node -> Map.has_key?(Map.get(graph, node, %{}), node) end)
        nodes -> length(nodes) > 1
      end)

    :digraph.delete(g)
    count
  end
end

Foundry.XrefCheck.run(System.argv())
