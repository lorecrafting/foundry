defmodule Foundry.ManualLane.MCPTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../../bin/foundry-mcp", __DIR__)
  @init %{
    "protocolVersion" => "2025-11-25",
    "capabilities" => %{},
    "clientInfo" => %{"name" => "fixture", "version" => "1.0.0"}
  }
  @status %{
    "jsonrpc" => "2.0",
    "id" => 5,
    "method" => "tools/call",
    "params" => %{
      "name" => "manual_lane_status",
      "arguments" => %{"ticket_id" => "ML-PG-MANUAL-MCP-PREVIEW"}
    }
  }

  test "stdio negotiation and discovery refuse malformed requests and CLI errors" do
    root = temp_root()
    input = Path.join(root, "requests.jsonl")

    requests = [
      %{"jsonrpc" => "2.0", "id" => 1, "method" => "initialize", "params" => @init},
      %{"jsonrpc" => "2.0", "method" => "notifications/initialized"},
      %{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"},
      %{"jsonrpc" => "2.0", "id" => 3, "method" => "anything/else"},
      put_in(@status, ["id"], 4)
      |> put_in(["params", "arguments", "ticket_id"], "../unsafe"),
      @status,
      %{"jsonrpc" => "2.0", "id" => 6, "method" => "initialize", "params" => false},
      %{"jsonrpc" => "2.0", "id" => 7, "method" => "initialize"},
      %{
        "jsonrpc" => "2.0",
        "id" => 8,
        "method" => "initialize",
        "params" => Map.put(@init, "protocolVersion", 9)
      },
      %{
        "jsonrpc" => "2.0",
        "id" => 9,
        "method" => "initialize",
        "params" => Map.put(@init, "capabilities", [])
      },
      %{
        "jsonrpc" => "2.0",
        "id" => 10,
        "method" => "initialize",
        "params" => Map.put(@init, "clientInfo", false)
      },
      %{
        "jsonrpc" => "2.0",
        "id" => 11,
        "method" => "initialize",
        "params" => Map.delete(@init, "clientInfo")
      },
      %{
        "jsonrpc" => "2.0",
        "id" => 12,
        "method" => "initialize",
        "params" => put_in(@init, ["clientInfo", "name"], false)
      },
      %{
        "jsonrpc" => "2.0",
        "id" => 13,
        "method" => "initialize",
        "params" => put_in(@init, ["clientInfo", "version"], false)
      },
      %{"jsonrpc" => "2.0", "id" => 14, "method" => "tools/list", "params" => "invalid"},
      %{"jsonrpc" => "2.0", "id" => 15, "method" => "ping", "params" => 42},
      %{
        "jsonrpc" => "2.0",
        "id" => 16,
        "method" => "initialize",
        "params" => Map.put(@init, "protocolVersion", "2026-07-28")
      }
    ]

    File.write!(input, Enum.map_join(requests, "\n", &JSON.encode!/1) <> "\nnot-json\n")
    responses = run(input, [{"FOUNDRY_RELEASE", Path.join(root, "missing-release")}])

    assert Enum.map(responses, & &1["id"]) == Enum.to_list(1..16) ++ [nil]
    assert get_in(Enum.at(responses, 0), ["result", "protocolVersion"]) == "2025-11-25"

    assert get_in(Enum.at(responses, 1), ["result", "tools"]) |> Enum.map(& &1["name"]) == [
             "manual_lane_status"
           ]

    assert get_in(Enum.at(responses, 2), ["error", "code"]) == -32601
    assert get_in(Enum.at(responses, 3), ["error", "code"]) == -32602
    assert get_in(Enum.at(responses, 4), ["result", "isError"]) == true

    for index <- 5..14 do
      assert get_in(Enum.at(responses, index), ["error", "code"]) == -32602
    end

    assert get_in(Enum.at(responses, 15), ["result", "protocolVersion"]) == "2025-11-25"
    assert get_in(Enum.at(responses, 16), ["error", "code"]) == -32700
  end

  test "raw UTF-8 initialize and string IDs roundtrip without ending the session" do
    root = temp_root()
    input = Path.join(root, "requests.jsonl")

    File.write!(
      input,
      ~s({"jsonrpc":"2.0","id":"café","method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"雪","version":"1"}}}) <>
        "\n" <>
        ~s({"jsonrpc":"2.0","id":"雪-2","method":"ping"}) <>
        "\n" <>
        ~S({"jsonrpc":"2.0","id":"caf\u00e9","method":"ping"}) <> "\n"
    )

    responses = run(input, [])
    assert Enum.map(responses, & &1["id"]) == ["café", "雪-2", "café"]
    assert get_in(hd(responses), ["result", "protocolVersion"]) == "2025-11-25"
    assert Enum.map(tl(responses), & &1["result"]) == [%{}, %{}]
  end

  test "status returns a small CLI result and refuses output beyond 16 KiB" do
    root = temp_root()
    release = Path.join(root, "fake-release")
    fixture = Path.join(root, "status-output")
    input = Path.join(root, "request.jsonl")
    File.write!(release, "#!/bin/sh\ncat \"$FOUNDRY_MCP_FIXTURE\"\n")
    File.chmod!(release, 0o755)
    File.write!(input, JSON.encode!(@status) <> "\n")

    for {body, oversized?} <- [
          {~s({"ok":true,"mode":"ready","tickets":{}}), false},
          {String.duplicate("x", 16_384), false},
          {String.duplicate("x", 16_385), true},
          {String.duplicate("é", 8_192), false},
          {String.duplicate("é", 8_193), true}
        ] do
      File.write!(fixture, body)

      [response] =
        run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_FIXTURE", fixture}])

      result = response["result"]
      assert result["isError"] == oversized?

      if oversized? do
        assert result["content"] == [
                 %{"type" => "text", "text" => "Ticket status exceeds 16 KiB"}
               ]
      else
        assert result["content"] == [%{"type" => "text", "text" => body}]
      end
    end
  end

  defp temp_root do
    root =
      Path.join(
        if(File.dir?("/private/tmp"), do: "/private/tmp", else: System.tmp_dir!()),
        "foundry-mcp-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    root
  end

  defp run(input, env) do
    {out, 0} =
      System.cmd("/bin/sh", ["-c", "exec elixir \"$1\" < \"$2\"", "sh", @script, input], env: env)

    out |> String.split("\n", trim: true) |> Enum.map(&JSON.decode!/1)
  end
end
