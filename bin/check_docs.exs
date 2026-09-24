# Documentation check: every relative Markdown link in a tracked file resolves to a
# tracked file. No Mix deps, database, models or live state.
#
#   elixir bin/check_docs.exs
root = Path.expand("..", __DIR__)
{files, 0} = System.cmd("git", ["ls-files", "-z"], cd: root)
tracked = files |> String.split(<<0>>, trim: true) |> MapSet.new()

broken =
  for file <- tracked,
      String.ends_with?(file, ".md"),
      [_, target] <- Regex.scan(~r/\]\(([^)\s]+)\)/, File.read!(Path.join(root, file))),
      not String.match?(target, ~r/\A([a-z][a-z0-9+.-]*:|#)/),
      path = target |> String.split("#") |> hd() |> URI.decode(),
      resolved = Path.join(Path.dirname(file), path) |> Path.expand("/r") |> Path.relative_to("/r"),
      not (MapSet.member?(tracked, resolved) or
             Enum.any?(tracked, &String.starts_with?(&1, resolved <> "/"))),
      do: "#{file}: #{target}"

Enum.each(Enum.sort(broken), &IO.puts/1)
IO.puts("#{length(broken)} broken link(s)")
System.halt(if broken == [], do: 0, else: 1)
