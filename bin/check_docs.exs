# Documentation check: every relative Markdown link in a tracked file resolves to a file
# or directory in the working tree (F18: a new, unstaged file counts), and every `#anchor`
# into a Markdown file names one of its headings (GitHub slug rules) or `id="…"` tags. No
# Mix deps, database, models or live state.
#
#   elixir bin/check_docs.exs
root = Path.expand("..", __DIR__)
{files, 0} = System.cmd("git", ["ls-files", "-z", "--", "*.md"], cd: root)

slug = fn heading ->
  heading
  |> String.replace(~r/\[([^\]]*)\]\([^)]*\)/, "\\1")
  |> String.trim()
  |> String.downcase()
  |> String.replace(~r/[^\p{L}\p{N}_\- ]/u, "")
  |> String.replace(" ", "-")
end

# Headings outside fenced code; a repeated slug gets -1, -2, ... as on GitHub.
anchors = fn text ->
  {slugs, _, _} =
    text
    |> String.split("\n")
    |> Enum.reduce({[], %{}, false}, fn line, {acc, seen, fence} ->
      cond do
        String.starts_with?(line, "```") -> {acc, seen, not fence}
        fence -> {acc, seen, fence}
        match = Regex.run(~r/\A\#{1,6} (.*)/, line) ->
          s = slug.(Enum.at(match, 1))
          n = Map.get(seen, s, 0)
          {[if(n == 0, do: s, else: "#{s}-#{n}") | acc], Map.put(seen, s, n + 1), fence}
        true -> {acc, seen, fence}
      end
    end)

  MapSet.new(slugs ++ (Regex.scan(~r/id="([^"]+)"/, text) |> Enum.map(&Enum.at(&1, 1))))
end

broken =
  for file <- String.split(files, <<0>>, trim: true),
      File.regular?(Path.join(root, file)),
      [_, target] <- Regex.scan(~r/\]\(([^)\s]+)\)/, File.read!(Path.join(root, file))),
      not String.match?(target, ~r/\A[a-z][a-z0-9+.-]*:/),
      [path | fragment] = String.split(target, "#", parts: 2),
      resolved =
        if(path == "", do: file, else: Path.join(Path.dirname(file), URI.decode(path)))
        |> Path.expand("/r")
        |> Path.relative_to("/r"),
      full = Path.join(root, resolved),
      not File.exists?(full) or
        (fragment != [] and String.ends_with?(resolved, ".md") and File.regular?(full) and
           not MapSet.member?(anchors.(File.read!(full)), hd(fragment))),
      do: "#{file}: #{target}"

Enum.each(Enum.sort(broken), &IO.puts/1)
IO.puts("#{length(broken)} broken link(s)")
System.halt(if broken == [], do: 0, else: 1)
