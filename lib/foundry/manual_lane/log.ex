defmodule Foundry.ManualLane.Log do
  @moduledoc """
  Observation, never authority (boundary rule 9): the `lane log` trail and the operator log.

  `trail/2` reads the lane store read-only over SQLite, as `Replay` does, so it also runs
  while the Gateway is in recovery: per ticket, its committed events in commit order, the
  refused commands Core recorded under its command ids, and each effect's
  `effect_observation_page`, with a review receipt's notes body from the archive beside the
  store (`archive_notes/2`). `operator/2` appends one JSON line per lane command to
  `operator.log.jsonl` beside the store. Nothing reads either back to decide anything.
  """

  alias Exqlite.Sqlite3
  alias Foundry.DurableStore.{Database, ProtectedPrimitives}

  @page %{
    "schema_version" => 1,
    "type" => "effect_observation_page",
    "limit" => 50,
    "max_bytes" => 262_144
  }

  # Core records a refused root command or bundle under its command id; every lane command
  # id begins with its ticket id and a slash.
  @refusals "SELECT command_id, actor_id, reason_code FROM atomic_bundles " <>
              "WHERE disposition != 'accepted' UNION ALL " <>
              "SELECT command_id, actor_id, reason_code FROM root_commands " <>
              "WHERE disposition != 'accepted'"

  @doc "`{:ok, %{ticket_id => trail}}` for one ticket or, with nil, every admitted one."
  def trail(path, ticket_id) do
    with {:ok, conn} <- Sqlite3.open(path, mode: :readonly) do
      try do
        read(conn, path, ticket_id)
      after
        Sqlite3.close(conn)
      end
    end
  end

  defp read(conn, store_path, ticket_id) do
    with {:ok, rows} <- Database.query(conn, "SELECT seq, event FROM events ORDER BY seq"),
         {:ok, refusals} <- Database.query(conn, @refusals) do
      events = for [seq, bytes] <- rows, do: event(seq, JSON.decode!(bytes))

      ids =
        if ticket_id,
          do: [ticket_id],
          else: for(%{"type" => "ticket_admitted", "ticket_id" => id} <- events, do: id)

      Enum.reduce_while(ids, {:ok, %{}}, fn id, {:ok, acc} ->
        case effects(conn, store_path, id) do
          {:ok, effects} ->
            trail = %{
              "events" => Enum.filter(events, &(&1["ticket_id"] == id)),
              "refusals" =>
                for(
                  [command_id, actor, reason] <- refusals,
                  String.starts_with?(command_id, id <> "/"),
                  do: %{"command_id" => command_id, "actor" => actor, "reason_code" => reason}
                ),
              "effects" => effects
            }

            {:cont, {:ok, Map.put(acc, id, trail)}}

          error ->
            {:halt, error}
        end
      end)
    end
  end

  # Seq, type and the payload's scalar fields; nested specs and projections are left out.
  defp event(seq, event) do
    event["payload"]
    |> Map.reject(fn {_key, value} -> is_map(value) or is_list(value) end)
    |> Map.merge(%{"seq" => seq, "type" => event["type"]})
  end

  defp effects(conn, store_path, ticket_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT effect_id FROM root_effects WHERE ticket_id = ? ORDER BY rowid",
             [ticket_id]
           ) do
      Enum.reduce_while(rows, {:ok, []}, fn [effect_id], {:ok, acc} ->
        with {:ok, page} <- observation(conn, effect_id, nil, nil),
             {:ok, principals} <- principals(conn, page),
             {:ok, notes} <- receipt_notes(conn, store_path, page) do
          page = Map.merge(page, %{"principals" => principals, "notes" => notes})
          {:cont, {:ok, acc ++ [page]}}
        else
          error -> {:halt, error}
        end
      end)
    end
  end

  # Every page of the effect's observation, its relations concatenated.
  defp observation(conn, effect_id, cursor, acc) do
    query = Map.merge(@page, %{"effect_id" => effect_id, "cursor" => cursor})

    with {:ok, page} <- ProtectedPrimitives.query(conn, query) do
      page = if acc, do: %{acc | "relations" => acc["relations"] ++ page["relations"]}, else: page

      case page["page"]["next_cursor"] do
        nil -> {:ok, Map.delete(page, "page")}
        next -> observation(conn, effect_id, next, page)
      end
    end
  end

  # The page names neither principal: the issuer is on the effect fact, the inbox's
  # authenticated actor on its row (none until an adapter streams into it).
  defp principals(conn, page) do
    query = %{
      "schema_version" => 1,
      "type" => "effect",
      "effect_id" => page["effect"]["effect_id"]
    }

    with {:ok, effect} <- ProtectedPrimitives.query(conn, query),
         {:ok, inbox} <-
           Database.query(
             conn,
             "SELECT actor_id FROM authenticated_inboxes WHERE execution_id = ?",
             [page["effect"]["execution_id"]]
           ) do
      {:ok, %{"issuer" => effect["issuer"], "inbox" => List.first(List.flatten(inbox))}}
    end
  end

  # F5: a review receipt records only its notes' digest; the body is read back from the
  # archive beside the store. Nil when no receipt of the effect names notes.
  defp receipt_notes(conn, store_path, page) do
    ids = for %{"kind" => "receipt", "receipt_id" => id} <- page["relations"], do: id

    Enum.reduce_while(ids, {:ok, nil}, fn id, acc ->
      query = %{"schema_version" => 1, "type" => "receipt", "receipt_id" => id}

      case ProtectedPrimitives.query(conn, query) do
        {:ok, %{"payload" => %{"notes_sha256" => digest}}} ->
          body =
            case notes(store_path, digest) do
              {:ok, body} -> body
              {:error, _} -> nil
            end

          notes = %{"sha256" => digest, "path" => notes_path(store_path, digest), "body" => body}
          {:halt, {:ok, notes}}

        {:ok, _receipt} ->
          {:cont, acc}

        error ->
          {:halt, error}
      end
    end)
  end

  @doc "Where the notes body with this SHA-256 digest is archived: `notes/` beside the store."
  def notes_path(store_path, digest),
    do: Path.join([Path.dirname(store_path), "notes", digest <> ".md"])

  @doc """
  F5: archives a review's notes body beside the store, content-addressed by its SHA-256, so
  it outlives the file the reviewer passed. Written to a temporary file and renamed, then
  read back and verified: `{:ok, digest}` or `{:error, reason}`.
  """
  def archive_notes(store_path, body) do
    digest = sha256(body)
    path = notes_path(store_path, digest)
    tmp = "#{path}.#{System.unique_integer([:positive])}.tmp"

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(tmp, body),
         :ok <- File.rename(tmp, path),
         {:ok, ^body} <- notes(store_path, digest) do
      {:ok, digest}
    else
      {:error, reason} ->
        File.rm(tmp)
        {:error, reason}
    end
  end

  @doc "The archived notes body for `digest`, verified against it."
  def notes(store_path, digest) do
    with {:ok, body} <- File.read(notes_path(store_path, digest)) do
      if sha256(body) == digest, do: {:ok, body}, else: {:error, :notes_digest_mismatch}
    end
  end

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  @doc "The trail as text: one line per event, refusal and effect relation."
  def text(%{"mode" => mode, "trail" => tickets}) do
    ["mode: #{mode}\n"] ++
      for {id, t} <- Enum.sort(tickets) do
        [
          "\n#{id}\n  events:\n",
          for(e <- t["events"], do: "    #{e["seq"]} #{e["type"]} #{fields(e)}\n"),
          "  refusals:\n",
          for(
            r <- t["refusals"],
            do: "    #{r["reason_code"]} #{r["command_id"]} by #{r["actor"]}\n"
          ),
          "  effects:\n",
          for(p <- t["effects"], do: effect_text(p))
        ]
      end
  end

  defp fields(event) do
    event
    |> Map.drop(~w(seq type ticket_id))
    |> Enum.sort()
    |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{if is_nil(v), do: "-", else: v}" end)
  end

  defp effect_text(page) do
    %{"issuer" => issuer, "inbox" => inbox} = page["principals"]

    [
      "    #{page["effect"]["effect_id"]} status=#{page["settlement"]["status"]} " <>
        "issuer=#{issuer} inbox=#{inbox || "-"} " <>
        "receipt_history=#{page["settlement"]["receipt_history"]}\n",
      for(r <- page["relations"], do: "      #{relation(r)}\n"),
      notes_text(page["notes"])
    ]
  end

  defp notes_text(nil), do: []

  defp notes_text(%{"sha256" => digest, "path" => path, "body" => nil}),
    do: "      notes sha256=#{digest} not archived at #{path}\n"

  defp notes_text(%{"sha256" => digest, "body" => body}) do
    indented = body |> String.trim_trailing() |> String.replace("\n", "\n        ")
    "      notes sha256=#{digest}\n        #{indented}\n"
  end

  defp relation(r) do
    r
    |> Map.drop(["schema_version"])
    |> Enum.sort()
    |> Enum.map_join(" ", fn {k, v} -> "#{k}=#{v}" end)
  end

  @doc """
  Appends one JSON line to `operator.log.jsonl` beside `store_path`. A failed write never
  changes the command's outcome; it prints a warning on stderr. Nil (no lane) writes nothing.
  """
  def operator(nil, _entry), do: :ok

  def operator(store_path, entry) do
    path = Path.join(Path.dirname(store_path), "operator.log.jsonl")

    case File.write(path, JSON.encode!(entry) <> "\n", [:append]) do
      :ok ->
        :ok

      {:error, reason} ->
        IO.puts(:stderr, "warning: operator log not written to #{path}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
