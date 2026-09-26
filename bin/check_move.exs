# Compare compiler-expanded definitions across a module split. Compile both revisions
# independently, then pass their ebin directories and module sets to this script.
# A declared addition that replaces a base function must be a single remote
# delegate to a candidate owner whose compiled body matches the base body.
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
    if length(Enum.uniq(declared)) != length(declared), do: raise("duplicate addition")

    # Declared additions are compared separately. Facade delegates intentionally
    # duplicate a moved key, but must point to its equivalent new owner.
    compared =
      base ++ Enum.reject(candidate, fn {mod, key, _, _, _} -> {mod, key} in declared end)

    ambiguous =
      compared
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 2))
      |> Enum.filter(fn {_, bodies} -> bodies |> Enum.uniq() |> length() > 1 end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    called =
      compared
      |> Enum.flat_map(&elem(&1, 4))
      |> Enum.map(&elem(&1, 1))
      |> MapSet.new()

    disputed = MapSet.intersection(ambiguous, called)

    if MapSet.size(disputed) > 0,
      do: raise("ambiguous split call: #{inspect(MapSet.to_list(disputed))}")

    Enum.each(declared, &check_addition!(&1, base, candidate, candidate_dir))

    unexpected =
      candidate
      |> Enum.reject(fn {mod, key, _, _, _} -> {mod, key} in declared end)
      |> Enum.map(&elem(&1, 2))
      |> Enum.frequencies()

    expected = base |> Enum.map(&elem(&1, 2)) |> Enum.frequencies()

    Enum.each(candidate_modules, fn mod ->
      count = Enum.count(candidate, fn {owner, _, _, _, _} -> owner == mod end)
      IO.puts("#{inspect(mod)}: #{count} definitions")
    end)

    promoted =
      for {_, key, _, :def, _} <- candidate,
          {_, ^key, _, :defp, _} <- base,
          do: key

    IO.puts("former defp promoted: #{inspect(Enum.uniq(promoted))}")

    if unexpected != expected or
         Enum.any?(declared, fn key ->
           Enum.count(candidate, fn {mod, name, _, _, _} -> {mod, name} == key end) != 1
         end) do
      IO.puts(:stderr, "compiled definitions differ: #{inspect(diff(expected, unexpected))}")
      System.halt(1)
    end

    IO.puts("compiled definitions match")
  end

  def run(_),
    do:
      raise(
        "usage: elixir bin/check_move.exs BASE_EBIN CANDIDATE_EBIN BASE_MODULES CANDIDATE_MODULES [MODULE.function/arity ...] [--lint-protected FILE ...]"
      )

  defp lint_protected!(path) do
    ast = path |> File.read!() |> Code.string_to_quoted!(file: path)

    {_ast, violations} =
      Macro.prewalk(ast, [], fn
        {:__MODULE__, _, _} = node, acc ->
          {node, ["__MODULE__" | acc]}

        {kind, _, _} = node, acc when kind in [:alias, :import, :require] ->
          text = Macro.to_string(node)
          if allowed_directive?(kind, text), do: {node, acc}, else: {node, [text | acc]}

        node, acc ->
          {node, acc}
      end)

    if violations != [],
      do:
        raise("#{path}: forbidden split directive: #{Enum.join(Enum.reverse(violations), ", ")}")
  end

  defp allowed_directive?(:alias, text) do
    String.match?(text, ~r/^alias Foundry\.DurableStore\.(Database|Encoding|TransitionPlan)$/) or
      String.match?(
        text,
        ~r/^alias Foundry\.DurableStore\.\{(Database|Encoding|TransitionPlan)(, (Database|Encoding|TransitionPlan))*\}$/
      )
  end

  defp allowed_directive?(:import, text),
    do:
      String.match?(
        text,
        ~r/^import Foundry\.DurableStore\.Protected\.[A-Z][A-Za-z]+(?:, only: \[[a-z_?!]+: \d+(?:, [a-z_?!]+: \d+)*\])?$/
      )

  defp allowed_directive?(_, _), do: false

  defp modules(csv),
    do: csv |> String.split(",", trim: true) |> Enum.map(&String.to_atom("Elixir." <> &1))

  defp addition(value) do
    [module_and_name, arity] = String.split(value, "/")
    parts = String.split(module_and_name, ".")

    {String.to_atom("Elixir." <> (parts |> Enum.drop(-1) |> Enum.join("."))),
     {String.to_atom(List.last(parts)), String.to_integer(arity)}}
  end

  defp check_addition!({base_owner, key} = added, base, candidate, candidate_dir) do
    base_bodies = for {^base_owner, ^key, body, _, _} <- base, do: body

    if base_bodies != [] do
      owners =
        for {owner, ^key, body, _, _} <- candidate,
            {owner, key} != added and body in base_bodies,
            do: owner

      unless forwarding_target(candidate_dir, base_owner, key) in owners,
        do: raise("declared delegate target differs: #{inspect(added)}")
    end
  end

  defp forwarding_target(dir, mod, {name, arity} = key) do
    beam = Path.join(dir, "#{mod}.beam")
    {:ok, {^mod, [debug_info: {:debug_info_v1, backend, data}]}} =
      :beam_lib.chunks(String.to_charlist(beam), [:debug_info])

    {:ok, %{definitions: defs}} = backend.debug_info(:elixir_v1, mod, data, [])

    case Enum.find(defs, fn {found, _, _, _} -> found == key end) do
      {^key, :def, _, [{_, args, [], {{:., _, [target, ^name]}, _, forwarded}}]}
      when is_list(args) and length(args) == arity and is_list(forwarded) ->
        if normalize(args, MapSet.new()) == normalize(forwarded, MapSet.new()),
          do: target,
          else: nil

      _ ->
        nil
    end
  end

  defp definitions(dir, modules, split) do
    Enum.flat_map(modules, fn mod ->
      beam = Path.join(dir, "#{mod}.beam")

      {:ok, {^mod, [debug_info: {:debug_info_v1, backend, data}]}} =
        :beam_lib.chunks(String.to_charlist(beam), [:debug_info])

      {:ok, %{definitions: defs}} = backend.debug_info(:elixir_v1, mod, data, [])
      IO.puts("#{inspect(mod)}: #{length(defs)} source definitions")

      Enum.map(defs, fn {key, kind, _, clauses} ->
        {mod, key, {key, if(kind == :defp, do: :def, else: kind), normalize(clauses, split)},
         kind, call_sites(clauses, split)}
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

      {meta, args, guards, body} when is_list(meta) ->
        {[], normalize(args, split), normalize(guards, split), normalize(body, split)}

      tuple when is_tuple(tuple) ->
        tuple |> Tuple.to_list() |> Enum.map(&normalize(&1, split)) |> List.to_tuple()

      list when is_list(list) ->
        Enum.map(list, &normalize(&1, split))

      other ->
        other
    end
  end

  defp call_sites({{:., _, [mod, fun]}, _, args}, split) when is_atom(mod) and is_list(args) do
    nested = Enum.flat_map(args, &call_sites(&1, split))
    if MapSet.member?(split, mod), do: [{mod, {fun, length(args)}} | nested], else: nested
  end

  defp call_sites({name, _, args}, split) when is_atom(name) and is_list(args) do
    [{nil, {name, length(args)}} | Enum.flat_map(args, &call_sites(&1, split))]
  end

  defp call_sites(tuple, split) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.flat_map(&call_sites(&1, split))

  defp call_sites(list, split) when is_list(list), do: Enum.flat_map(list, &call_sites(&1, split))
  defp call_sites(_, _), do: []

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
