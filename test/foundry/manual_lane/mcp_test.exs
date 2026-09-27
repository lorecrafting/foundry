defmodule Foundry.ManualLane.MCPTest do
  use ExUnit.Case, async: true

  @script Path.expand("../../../bin/foundry-mcp", __DIR__)

  test "stdio negotiation, discovery and bounded manual status refuse malformed inputs" do
    root =
      Path.join(
        if(File.dir?("/private/tmp"), do: "/private/tmp", else: System.tmp_dir!()),
        "foundry-mcp-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    input = Path.join(root, "requests.jsonl")

    requests = [
      %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{"protocolVersion" => "2025-11-25", "capabilities" => %{}}
      },
      %{"jsonrpc" => "2.0", "method" => "notifications/initialized"},
      %{"jsonrpc" => "2.0", "id" => 2, "method" => "tools/list"},
      %{"jsonrpc" => "2.0", "id" => 3, "method" => "anything/else"},
      %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "tools/call",
        "params" => %{
          "name" => "manual_lane_status",
          "arguments" => %{"ticket_id" => "../unsafe"}
        }
      },
      %{
        "jsonrpc" => "2.0",
        "id" => 5,
        "method" => "tools/call",
        "params" => %{
          "name" => "manual_lane_status",
          "arguments" => %{"ticket_id" => "ML-PG-MANUAL-MCP-PREVIEW"}
        }
      }
    ]

    File.write!(input, Enum.map_join(requests, "\n", &JSON.encode!/1) <> "\nnot-json\n")

    {out, 0} =
      System.cmd("/bin/sh", ["-c", "exec elixir \"$1\" < \"$2\"", "sh", @script, input],
        env: [{"FOUNDRY_RELEASE", Path.join(root, "missing-release")}]
      )

    responses = out |> String.split("\n", trim: true) |> Enum.map(&JSON.decode!/1)
    assert Enum.map(responses, & &1["id"]) == [1, 2, 3, 4, 5, nil]
    assert get_in(Enum.at(responses, 0), ["result", "protocolVersion"]) == "2025-11-25"

    assert get_in(Enum.at(responses, 1), ["result", "tools"]) |> Enum.map(& &1["name"]) == [
             "manual_lane_status"
           ]

    assert get_in(Enum.at(responses, 2), ["error", "code"]) == -32601
    assert get_in(Enum.at(responses, 3), ["error", "code"]) == -32602
    assert get_in(Enum.at(responses, 4), ["result", "isError"]) == true
    assert get_in(Enum.at(responses, 5), ["error", "code"]) == -32700
  end
end
