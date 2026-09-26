if Mix.env() in [:dev, :test] do
  defmodule Mix.Tasks.Foundry.Move do
    use Mix.Task
    use Boundary, classify_to: Foundry

    @shortdoc "Move named functions between single-module Elixir files"
    @moduledoc """
    `mix foundry.move --from SOURCE --to TARGET --module Target.Module --functions f/1,g/2`

    `--module` is required when TARGET does not exist. Move all clauses of each
    named function together. Local callers crossing the move boundary, captures,
    dynamic calls, module attributes, macros, imports, alias chains and conflicts
    are refused before either file is written. Changes are staged in both
    directories so a destination failure leaves the source intact. Cross-module
    caller rewrites in the Gateway and ProtectedPrimitives splits remain manual
    and are checked with `bin/check_move.exs` against compiled revisions.
    """

    @impl true
    def run(argv) do
      {opts, rest, invalid} =
        OptionParser.parse(argv,
          strict: [from: :string, to: :string, module: :string, functions: :string]
        )

      if rest != [] or invalid != [], do: Mix.raise("invalid move options")
      from = Keyword.fetch!(opts, :from)
      to = Keyword.fetch!(opts, :to)

      names =
        opts
        |> Keyword.fetch!(:functions)
        |> String.split(",", trim: true)
        |> Enum.map(&signature/1)

      if names == [] or Path.expand(from) == Path.expand(to),
        do: Mix.raise("provide functions and distinct files")

      if not File.dir?(Path.dirname(to)), do: Mix.raise("destination parent does not exist")

      source = File.read!(from)
      source_ast = Sourceror.parse_string!(source)
      {source_module, source_nodes, _source_meta} = module_parts(source_ast)

      {target, target_ast} =
        if File.exists?(to) do
          text = File.read!(to)
          {text, Sourceror.parse_string!(text)}
        else
          module = Keyword.get(opts, :module) || Mix.raise("--module required for a new target")
          text = "defmodule #{module} do\nend\n"
          {text, Sourceror.parse_string!(text)}
        end

      {target_module, target_nodes, target_meta} = module_parts(target_ast)
      if source_module == target_module, do: Mix.raise("source and target module are the same")

      if Keyword.has_key?(opts, :module) and Keyword.get(opts, :module) != target_module,
        do: Mix.raise("--module does not match target")

      selected_defs = Enum.filter(source_nodes, &(movable?(&1) and definition(&1) in names))
      found = selected_defs |> Enum.map(&definition/1) |> MapSet.new()
      if found != MapSet.new(names), do: Mix.raise("a named function is absent")

      attached = decorators(source_nodes, selected_defs)
      selected = Enum.filter(source_nodes, &(&1 in selected_defs or &1 in attached))

      retained = source_nodes -- selected

      source_defs =
        source_nodes |> Enum.map(&definition/1) |> Enum.reject(&is_nil/1) |> MapSet.new()

      moved_defs = MapSet.new(names)

      target_defs =
        target_nodes |> Enum.map(&definition/1) |> Enum.reject(&is_nil/1) |> MapSet.new()

      if not MapSet.disjoint?(moved_defs, target_defs),
        do: Mix.raise("target definition conflicts")

      if Enum.any?(source_nodes ++ target_nodes, &directive?/1),
        do: Mix.raise("import, require or use needs a manual move")

      if Enum.any?(selected_defs, &unsafe_body?/1),
        do: Mix.raise("module attributes, dynamic calls or __MODULE__ need a manual move")

      if calls?(selected, MapSet.difference(source_defs, moved_defs)) or
           calls?(retained, moved_defs) or ambiguous_caller?(retained),
         do: Mix.raise("local calls cross the move boundary")

      aliases = aliases(source_nodes)
      target_aliases = aliases(target_nodes)
      used = selected |> Enum.flat_map(&alias_roots/1) |> MapSet.new()

      first_moved_line =
        selected_defs |> Enum.map(fn {_, meta, _} -> meta[:line] end) |> Enum.min()

      Enum.each(used, fn short ->
        if Map.has_key?(target_aliases, short) and not Map.has_key?(aliases, short),
          do: Mix.raise("alias #{short} conflicts in target")

        case Map.get(aliases, short) do
          {full, {:alias, meta, _}} ->
            if Map.has_key?(target_aliases, hd(full)),
              do: Mix.raise("alias #{hd(full)} conflicts in target")

            if meta[:line] >= first_moved_line,
              do: Mix.raise("alias #{short} is declared after the moved function")

          nil ->
            :ok
        end
      end)

      still_used =
        retained
        |> Enum.reject(&match?({:alias, _, _}, &1))
        |> Enum.flat_map(&alias_roots/1)
        |> MapSet.new()

      additions =
        Enum.flat_map(aliases, fn {short, {full, node}} ->
          if MapSet.member?(used, short) do
            case Map.get(target_aliases, short) do
              nil -> [node]
              {^full, _} -> []
              _ -> Mix.raise("alias #{short} conflicts in target")
            end
          else
            []
          end
        end)

      alias_removals =
        for {short, {_full, node}} <- aliases,
            MapSet.member?(used, short) and not MapSet.member?(still_used, short),
            do: node

      removals =
        Enum.map(alias_removals ++ selected, fn node ->
          Sourceror.Patch.new(Sourceror.get_range(node, include_comments: true), "", false)
        end)

      changed_source = Sourceror.patch_string(source, removals)
      insertion = Enum.map_join(additions ++ selected, "\n\n", &indent(Sourceror.to_string(&1)))
      end_pos = Keyword.fetch!(target_meta, :end)
      insert_range = %{start: end_pos, end: end_pos}

      changed_target =
        Sourceror.patch_string(target, [
          Sourceror.Patch.new(insert_range, insertion <> "\n", false)
        ])

      # Parse both results before writing either file.
      Sourceror.parse_string!(changed_source)
      Sourceror.parse_string!(changed_target)
      write_pair!(from, to, changed_source, changed_target, target, File.exists?(to))

      Mix.shell().info(
        "moved #{length(selected_defs)} clause(s) from #{source_module} to #{target_module}"
      )
    end

    defp signature(text) do
      case String.split(text, "/") do
        [name, arity] -> {String.to_atom(name), String.to_integer(arity)}
        _ -> Mix.raise("expected name/arity: #{text}")
      end
    end

    defp module_parts({:defmodule, meta, [name, [{_, body}]]}) do
      {Macro.to_string(name), nodes(body), meta}
    end

    defp module_parts(_), do: Mix.raise("expected exactly one top-level defmodule")
    defp nodes({:__block__, _, list}), do: list
    defp nodes(nil), do: []
    defp nodes(one), do: [one]

    defp definition({kind, _, [head | _]})
         when kind in [:def, :defp, :defmacro, :defmacrop, :defdelegate] do
      head = if match?({:when, _, _}, head), do: head |> elem(2) |> hd(), else: head
      {name, _, args} = head
      {name, length(args || [])}
    end

    defp definition(_), do: nil
    defp movable?({kind, _, _}) when kind in [:def, :defp], do: true
    defp movable?(_), do: false
    defp decorator?({:@, _, [{name, _, _}]}), do: name in [:doc, :spec, :impl]
    defp decorator?(_), do: false

    defp decorators(nodes, selected_defs) do
      Enum.flat_map(selected_defs, fn selected ->
        index = Enum.find_index(nodes, &(&1 == selected))
        nodes |> Enum.take(index) |> Enum.reverse() |> Enum.take_while(&decorator?/1)
      end)
    end

    defp directive?({kind, _, _}) when kind in [:import, :require, :use, :defmodule], do: true
    defp directive?(_), do: false

    defp unsafe_body?(node) do
      {_node, bad} =
        Macro.prewalk(node, false, fn
          {kind, _, _} = ast, _
          when kind in [
                 :@,
                 :__MODULE__,
                 :&,
                 :apply,
                 :import,
                 :require,
                 :use,
                 :quote,
                 :unquote,
                 :\\
               ] ->
            {ast, true}

          ast, bad ->
            {ast, bad}
        end)

      bad
    end

    defp calls?(nodes, signatures) do
      Enum.any?(nodes, fn node ->
        {_node, found} =
          Macro.prewalk(node, false, fn
            {:|>, _, [_, {name, _, args}]} = ast, seen
            when is_atom(name) and (is_list(args) or is_nil(args)) ->
              {ast, seen or MapSet.member?(signatures, {name, length(args || []) + 1})}

            {:&, _, [{:/, _, [{name, _, _}, {:__block__, _, [arity]}]}]} = ast, seen
            when is_atom(name) and is_integer(arity) ->
              {ast, seen or MapSet.member?(signatures, {name, arity})}

            {:&, _, [{:/, _, [{name, _, _}, arity]}]} = ast, seen
            when is_atom(name) and is_integer(arity) ->
              {ast, seen or MapSet.member?(signatures, {name, arity})}

            {name, _, args} = ast, seen when is_atom(name) and is_list(args) ->
              {ast, seen or MapSet.member?(signatures, {name, length(args)})}

            ast, seen ->
              {ast, seen}
          end)

        found
      end)
    end

    defp ambiguous_caller?(nodes) do
      Enum.any?(nodes, fn node ->
        {_node, found} =
          Macro.prewalk(node, false, fn
            {kind, _, _} = ast, _ when kind in [:apply, :quote, :unquote] -> {ast, true}
            {{:., _, [_, kind]}, _, _} = ast, _ when kind in [:apply, :capture] -> {ast, true}
            ast, found -> {ast, found}
          end)

        found
      end)
    end

    defp aliases(nodes) do
      aliases =
        Enum.reduce(nodes, %{}, fn
          {:alias, _, _} = node, acc ->
            case Code.string_to_quoted(Sourceror.to_string(node)) do
              {:ok, {:alias, _, [{:__aliases__, _, full}]}} ->
                put_alias(acc, List.last(full), full, node)

              {:ok, {:alias, _, [{:__aliases__, _, full}, [as: {:__aliases__, _, [short]}]]}} ->
                put_alias(acc, short, full, node)

              _ ->
                Mix.raise("complex alias needs a manual move")
            end

          _, acc ->
            acc
        end)

      if Enum.any?(aliases, fn {_, {full, _}} -> Map.has_key?(aliases, hd(full)) end),
        do: Mix.raise("alias chain needs a manual move")

      aliases
    end

    defp put_alias(acc, short, full, node) do
      if Map.has_key?(acc, short), do: Mix.raise("ambiguous alias #{short}")
      Map.put(acc, short, {full, node})
    end

    defp alias_roots(node) do
      {_node, roots} =
        Macro.prewalk(node, [], fn
          {:__aliases__, _, [root | _]} = ast, acc -> {ast, [root | acc]}
          ast, acc -> {ast, acc}
        end)

      roots
    end

    defp indent(text), do: text |> String.split("\n") |> Enum.map_join("\n", &("  " <> &1))

    defp write_pair!(from, to, source, target, previous_target, existed?) do
      id = :erlang.unique_integer([:positive])
      source_tmp = Path.join(Path.dirname(from), ".foundry-move-#{id}-source")
      target_tmp = Path.join(Path.dirname(to), ".foundry-move-#{id}-target")
      rollback_tmp = Path.join(Path.dirname(to), ".foundry-move-#{id}-rollback")

      try do
        File.write!(source_tmp, source)
        File.write!(target_tmp, target)
        if existed?, do: File.write!(rollback_tmp, previous_target)
        File.rename!(target_tmp, to)

        try do
          File.rename!(source_tmp, from)
        rescue
          error ->
            if existed?, do: File.rename!(rollback_tmp, to), else: File.rm!(to)
            reraise error, __STACKTRACE__
        end
      after
        Enum.each([source_tmp, target_tmp, rollback_tmp], &File.rm/1)
      end
    end
  end
end
