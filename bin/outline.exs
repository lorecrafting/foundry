defmodule Foundry.Outline do
  def run(paths) do
    Enum.each(paths, fn path ->
      case File.read(path) do
        {:ok, source} ->
          case Code.string_to_quoted(source, token_metadata: true) do
            {:ok, ast} -> ast |> entries(nil) |> Enum.each(&IO.puts/1)
            {:error, error} -> raise "#{path}: #{inspect(error)}"
          end

        {:error, reason} ->
          raise "#{path}: #{:file.format_error(reason)}"
      end
    end)
  end

  defp entries({:__block__, _, nodes}, parent), do: Enum.flat_map(nodes, &entries(&1, parent))

  defp entries({:defmodule, meta, [name, [do: body]]}, parent) do
    module = module_name(name, parent)
    ["module #{module} #{span(meta)}" | entries(body, module)]
  end

  defp entries({kind, meta, [head | _]}, module) when kind in [:def, :defp, :defmacro, :defmacrop] do
    {name, arity} = head_name(head)
    ["#{kind} #{module}.#{name}/#{arity} #{span(meta)}"]
  end

  defp entries(_, _), do: []

  defp module_name({:__aliases__, _, parts}, nil), do: Enum.join(parts, ".")
  defp module_name({:__aliases__, _, [:Elixir | parts]}, _), do: Enum.join(parts, ".")
  defp module_name({:__aliases__, _, parts}, parent), do: parent <> "." <> Enum.join(parts, ".")
  defp module_name(name, nil) when is_atom(name), do: Atom.to_string(name)
  defp module_name(name, parent) when is_atom(name), do: parent <> "." <> Atom.to_string(name)

  defp head_name({:when, _, [head | _]}), do: head_name(head)
  defp head_name({name, _, args}), do: {name, length(args || [])}

  defp span(meta) do
    first = Keyword.fetch!(meta, :line)
    last = get_in(meta, [:end, :line]) || get_in(meta, [:end_of_expression, :line]) || first
    "#{first}-#{last}"
  end
end

case System.argv() do
  [] -> IO.puts(:stderr, "usage: elixir bin/outline.exs FILE ..."); System.halt(2)
  paths -> Foundry.Outline.run(paths)
end
