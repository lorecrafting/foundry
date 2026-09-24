# Documentation check: every relative Markdown link in a tracked file resolves to a file
# or directory in the working tree (F18: a new, unstaged file counts). No Mix deps,
# database, models or live state.
#
#   elixir bin/check_docs.exs
root = Path.expand("..", __DIR__)
{files, 0} = System.cmd("git", ["ls-files", "-z", "--", "*.md"], cd: root)

broken =
  for file <- String.split(files, <<0>>, trim: true),
      File.regular?(Path.join(root, file)),
      [_, target] <- Regex.scan(~r/\]\(([^)\s]+)\)/, File.read!(Path.join(root, file))),
      not String.match?(target, ~r/\A([a-z][a-z0-9+.-]*:|#)/),
      path = target |> String.split("#") |> hd() |> URI.decode(),
      resolved = Path.join(Path.dirname(file), path) |> Path.expand("/r") |> Path.relative_to("/r"),
      not File.exists?(Path.join(root, resolved)),
      do: "#{file}: #{target}"

Enum.each(Enum.sort(broken), &IO.puts/1)
IO.puts("#{length(broken)} broken link(s)")
System.halt(if broken == [], do: 0, else: 1)
