# Refresh the vendored Phoenix usage rules (docs/conventions/phoenix/) from upstream.
#
#   elixir bin/sync_phoenix_rules.exs            # newest stable Phoenix release
#   elixir bin/sync_phoenix_rules.exs v1.8.14    # a named tag
#
# Each file is written verbatim under a provenance header naming the tag and commit. Review
# the result with `git diff docs/conventions/phoenix`, then check that the overrides in
# docs/ELIXIR-CONVENTIONS.md still make sense against the new text. Needs `git` and `curl`.

defmodule SyncPhoenixRules do
  @repo "https://github.com/phoenixframework/phoenix"
  @raw "https://raw.githubusercontent.com/phoenixframework/phoenix"
  # Only the language rules apply: Foundry uses no Phoenix, Ecto, HEEx or LiveView.
  @files ~w(elixir.md)
  @dest Path.expand("../docs/conventions/phoenix", __DIR__)

  def main(args) do
    tags = remote_tags()

    tag =
      case args do
        [] -> newest_stable(tags)
        [tag] -> tag
        _ -> abort("usage: elixir bin/sync_phoenix_rules.exs [tag]")
      end

    commit = Map.get(tags, tag) || abort("no tag #{tag} in #{@repo}")
    File.mkdir_p!(@dest)

    for file <- @files do
      body = fetch("#{@raw}/#{commit}/usage-rules/#{file}")

      header =
        "<!-- Vendored from #{@repo}/blob/#{commit}/usage-rules/#{file} (#{tag}) by " <>
          "bin/sync_phoenix_rules.exs. Do not edit: Foundry's overrides are in " <>
          "docs/ELIXIR-CONVENTIONS.md. -->\n\n"

      File.write!(Path.join(@dest, file), header <> body)
      IO.puts("#{file}: #{tag} #{commit}")
    end
  end

  # tag => commit; an annotated tag's peeled `^{}` line names the commit and wins.
  defp remote_tags do
    {out, 0} = System.cmd("git", ["ls-remote", "--tags", @repo])

    for line <- String.split(out, "\n", trim: true),
        [sha, "refs/tags/" <> ref] = String.split(line, "\t"),
        reduce: %{} do
      acc ->
        case String.split(ref, "^{}") do
          [tag, ""] -> Map.put(acc, tag, sha)
          [tag] -> Map.put_new(acc, tag, sha)
        end
    end
  end

  defp newest_stable(tags) do
    tags
    |> Map.keys()
    |> Enum.flat_map(fn tag ->
      case Version.parse(String.trim_leading(tag, "v")) do
        {:ok, %Version{pre: []} = version} -> [{version, tag}]
        _ -> []
      end
    end)
    |> Enum.max_by(&elem(&1, 0), Version)
    |> elem(1)
  end

  defp fetch(url) do
    case System.cmd("curl", ["-fsSL", url]) do
      {body, 0} -> body
      {_, code} -> abort("curl exited #{code} for #{url}")
    end
  end

  defp abort(message) do
    IO.puts(:stderr, message)
    System.halt(1)
  end
end

SyncPhoenixRules.main(System.argv())
