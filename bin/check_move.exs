# Compare compiler-expanded definitions across a module split. Compile both revisions
# independently, then pass their ebin directories and module sets to this script.
defmodule Foundry.MoveCheck do
  def run([base_dir, candidate_dir, base_names, candidate_names | options]) do
    {additions, lint_option} = Enum.split_while(options, &(&1 != "--lint-protected"))
    lint_sources = if lint_option == [], do: [], else: tl(lint_option)
    if lint_option != [] and lint_sources == [], do: raise("--lint-protected needs source files")
    Enum.each(lint_sources, &lint_protected!/1)
    base_modules = modules(base_names)
    candidate_modules = modules(candidate_names)
    split = MapSet.new(base_modules ++ candidate_modules)
    base = definitions(base_dir, base_modules, split)
    candidate = definitions(candidate_dir, candidate_modules, split)
    declared = Enum.map(additions, &addition/1)

    unexpected =
      candidate
      |> Enum.reject(fn {mod, key, _, _} -> {mod, key} in declared end)
      |> Enum.map(&elem(&1, 2))
      |> Enum.frequencies()

    expected = base |> Enum.map(&elem(&1, 2)) |> Enum.frequencies()

    Enum.each(candidate_modules, fn mod ->
      count = Enum.count(candidate, fn {owner, _, _, _} -> owner == mod end)
      IO.puts("#{inspect(mod)}: #{count} definitions")
    end)

    promoted =
      for {_, key, _, :def} <- candidate,
          {_, ^key, _, :defp} <- base,
          do: key

    IO.puts("former defp promoted: #{inspect(Enum.uniq(promoted))}")

    if unexpected != expected or length(declared) != length(additions) or
         Enum.any?(declared, fn key -> Enum.count(candidate, fn {mod, name, _, _} -> {mod, name} == key end) != 1 end) do
      IO.puts(:stderr, "compiled definitions differ: #{inspect(diff(expected, unexpected))}")
      System.halt(1)
    end

    IO.puts("compiled definitions match")
  end

  def run(_),
    do: raise("usage: elixir bin/check_move.exs BASE_EBIN CANDIDATE_EBIN BASE_MODULES CANDIDATE_MODULES [MODULE.function/arity ...] [--lint-protected FILE ...]")

  defp lint_protected!(path) do
    ast = path |> File.read!() |> Code.string_to_quoted!(file: path)
    {_ast, violations} =
      Macro.prewalk(ast, [], fn
        {:__MODULE__, _, _} = node, acc -> {node, ["__MODULE__" | acc]}
        {kind, _, _} = node, acc when kind in [:alias, :import, :require] ->
          text = Macro.to_string(node)
          if allowed_directive?(kind, text), do: {node, acc}, else: {node, [text | acc]}

        node, acc -> {node, acc}
      end)

    if violations != [], do: raise("#{path}: forbidden split directive: #{Enum.join(Enum.reverse(violations), ", ")}")
  end

  defp allowed_directive?(:alias, text) do
    String.match?(text, ~r/^alias Foundry\.DurableStore\.(Database|Encoding|TransitionPlan)$/) or
      String.match?(text, ~r/^alias Foundry\.DurableStore\.\{(Database|Encoding|TransitionPlan)(, (Database|Encoding|TransitionPlan))*\}$/)
  end

  defp allowed_directive?(:import, text),
    do: String.match?(text, ~r/^import Foundry\.DurableStore\.Protected\.[A-Z][A-Za-z]+$/)

  defp allowed_directive?(_, _), do: false

  defp modules(csv), do: csv |> String.split(",", trim: true) |> Enum.map(&String.to_atom("Elixir." <> &1))

  defp addition(value) do
    [module_and_name, arity] = String.split(value, "/")
    parts = String.split(module_and_name, ".")
    {String.to_atom("Elixir." <> (parts |> Enum.drop(-1) |> Enum.join("."))),
     {String.to_atom(List.last(parts)), String.to_integer(arity)}}
  end

  defp definitions(dir, modules, split) do
    Enum.flat_map(modules, fn mod ->
      beam = Path.join(dir, "#{mod}.beam")

      {:ok, {^mod, [debug_info: {:debug_info_v1, backend, data}]}} =
        :beam_lib.chunks(String.to_charlist(beam), [:debug_info])

      {:ok, %{definitions: defs}} = backend.debug_info(:elixir_v1, mod, data, [])
      IO.puts("#{inspect(mod)}: #{length(defs)} source definitions")
      Enum.map(defs, fn {key, kind, _, clauses} ->
        {mod, key, {key, if(kind == :defp, do: :def, else: kind), normalize(clauses, split)}, kind}
      end)
    end)
  end

  defp normalize(term, split) do
    case term do
      {{:., _, [mod, fun]}, _, args} when is_atom(mod) and is_list(args) ->
        args = normalize(args, split)
        if MapSet.member?(split, mod), do: {fun, [], args}, else: {{:., [], [mod, fun]}, [], args}

      {head, meta, args} when is_list(meta) ->
        {normalize(head, split), [], normalize(args, split)}

      tuple when is_tuple(tuple) ->
        tuple |> Tuple.to_list() |> Enum.map(&normalize(&1, split)) |> List.to_tuple()

      list when is_list(list) -> Enum.map(list, &normalize(&1, split))
      other -> other
    end
  end

  defp diff(expected, actual) do
    %{missing: changed(expected, actual), extra: changed(actual, expected)}
  end

  defp changed(left, right) do
    for {{{name, arity}, _, _} = key, count} <- left,
        Map.get(right, key, 0) < count,
        do: {name, arity, count - Map.get(right, key, 0)}
  end
end

Foundry.MoveCheck.run(System.argv())
