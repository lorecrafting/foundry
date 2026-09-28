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
             "manual_lane_status",
             "manual_lane_integrated",
             "manual_lane_overview",
             "manual_lane_log",
             "manual_lane_admit",
             "manual_lane_developer_packet",
             "manual_lane_reviewer_packet",
             "manual_lane_submit",
             "manual_lane_review"
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

  test "read-only tools return small CLI results and refuse output beyond 16 KiB" do
    root = temp_root()
    release = Path.join(root, "fake-release")
    fixture = Path.join(root, "status-output")
    input = Path.join(root, "request.jsonl")
    File.write!(release, "#!/bin/sh\ncat \"$FOUNDRY_MCP_FIXTURE\"\n")
    File.chmod!(release, 0o755)

    for {tool, body, oversized?, error_text} <- [
          {"manual_lane_status", ~s({"ok":true,"mode":"ready","tickets":{}}), false, nil},
          {"manual_lane_status", String.duplicate("x", 16_384), false, nil},
          {"manual_lane_status", String.duplicate("x", 16_385), true,
           "Ticket status exceeds 16 KiB"},
          {"manual_lane_status", String.duplicate("é", 8_192), false, nil},
          {"manual_lane_status", String.duplicate("é", 8_193), true,
           "Ticket status exceeds 16 KiB"},
          {"manual_lane_integrated", ~s({"ok":true,"ref":"main","integrated":true}), false, nil},
          {"manual_lane_integrated", String.duplicate("x", 16_385), true,
           "Lane output exceeds 16 KiB"}
        ] do
      File.write!(input, JSON.encode!(call(tool, %{"ticket_id" => "ML-42"})) <> "\n")
      File.write!(fixture, body)

      [response] =
        run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_FIXTURE", fixture}])

      result = response["result"]
      assert result["isError"] == oversized?

      if oversized? do
        assert result["content"] == [%{"type" => "text", "text" => error_text}]
      else
        assert result["content"] == [%{"type" => "text", "text" => body}]
      end
    end

    File.write!(input, JSON.encode!(call("manual_lane_overview", %{})) <> "\n")
    File.write!(fixture, String.duplicate("x", 16_385))

    [overview] = run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_FIXTURE", fixture}])
    assert overview["result"]["isError"] == true

    assert overview["result"]["content"] == [
             %{"type" => "text", "text" => "Lane overview exceeds 16 KiB"}
           ]
  end

  test "log returns CLI text and bounds oversized output and errors" do
    root = temp_root()
    release = Path.join(root, "fake-release")
    fixture = Path.join(root, "log-output")
    input = Path.join(root, "request.jsonl")

    File.write!(
      release,
      "#!/bin/sh\ncat \"$FOUNDRY_MCP_FIXTURE\"\nexit \"${FOUNDRY_MCP_FAIL:-0}\"\n"
    )

    File.chmod!(release, 0o755)
    File.write!(input, JSON.encode!(call("manual_lane_log", %{"ticket_id" => "ML-42"})) <> "\n")

    for {body, exit_code, expected} <- [
          {~s({"ok":true,"events":[]}), 0, {false, ~s({"ok":true,"events":[]})}},
          {"refused", 1, {true, "refused"}},
          {String.duplicate("x", 16_385), 0, {true, "Lane log exceeds 16 KiB"}}
        ] do
      File.write!(fixture, body)

      [response] =
        run(input, [
          {"FOUNDRY_RELEASE", release},
          {"FOUNDRY_MCP_FIXTURE", fixture},
          {"FOUNDRY_MCP_FAIL", Integer.to_string(exit_code)}
        ])

      {is_error, text} = expected
      assert response["result"]["isError"] == is_error
      assert response["result"]["content"] == [%{"type" => "text", "text" => text}]
    end
  end

  test "CLI stderr does not corrupt successful JSON and supplies bounded failure diagnostics" do
    root = temp_root()
    release = Path.join(root, "fake-release")
    input = Path.join(root, "request.jsonl")

    File.write!(
      release,
      "#!/bin/sh\nprintf '%s' \"$FOUNDRY_MCP_STDOUT\"\nprintf '%s' \"$FOUNDRY_MCP_STDERR\" >&2\nexit \"$FOUNDRY_MCP_EXIT\"\n"
    )

    File.chmod!(release, 0o755)

    File.write!(
      input,
      JSON.encode!(call("manual_lane_status", %{"ticket_id" => "ML-42"})) <> "\n"
    )

    for {stdout, stderr, exit_code, is_error, text} <- [
          {~s({"ok":true}), "warning: diagnostic", "0", false, ~s({"ok":true})},
          {"", "error: lane unavailable", "1", true, "error: lane unavailable"},
          {"", "", "2", true, "Lane command exited 2 without output"},
          {"", String.duplicate("x", 16_385), "1", true, "Ticket status exceeds 16 KiB"}
        ] do
      [response] =
        run(input, [
          {"FOUNDRY_RELEASE", release},
          {"FOUNDRY_MCP_STDOUT", stdout},
          {"FOUNDRY_MCP_STDERR", stderr},
          {"FOUNDRY_MCP_EXIT", exit_code}
        ])

      assert response["result"]["isError"] == is_error
      assert response["result"]["content"] == [%{"type" => "text", "text" => text}]
    end
  end

  test "each allowed operation sends exact argv to the lane and exposes bounded schemas" do
    root = temp_root()
    {release, log} = fake_release(root)
    sha = String.duplicate("a", 40)
    common = %{"ticket_id" => "ML-42"}
    principal = %{"principal" => "agent:sol/dev-42"}

    calls = [
      {"manual_lane_status", common, ~w(lane status ML-42 --json)},
      {"manual_lane_integrated", common, ~w(lane integrated ML-42 --json)},
      {"manual_lane_overview", %{}, ~w(lane status --json)},
      {"manual_lane_log", common, ~w(lane log ML-42 --json)},
      {"manual_lane_admit",
       Map.merge(common, %{
         "base_ref" => sha,
         "title" => "Short title",
         "scope" => ["lib/a.ex", "test/a_test.exs"],
         "acceptance" => ["first", "second"]
       }),
       [
         "lane",
         "admit",
         "ML-42",
         "--base-ref",
         sha,
         "--title",
         "Short title",
         "--scope",
         "lib/a.ex,test/a_test.exs",
         "--acceptance",
         "first",
         "--acceptance",
         "second",
         "--json"
       ]},
      {"manual_lane_developer_packet",
       Map.merge(common, Map.merge(principal, %{"out" => "/tmp/dev.json"})),
       ~w(lane packet ML-42 --role developer --principal agent:sol/dev-42 --out /tmp/dev.json --json)},
      {"manual_lane_reviewer_packet",
       Map.merge(common, %{"principal" => "agent:astra/review-42", "out" => "/tmp/review.json"}),
       ~w(lane packet ML-42 --role reviewer --principal agent:astra/review-42 --out /tmp/review.json --json)},
      {"manual_lane_submit",
       Map.merge(
         common,
         Map.merge(principal, %{
           "candidate" => sha,
           "checkout" => "/tmp/work",
           "blocked" => "needs correction"
         })
       ),
       [
         "lane",
         "submit",
         "ML-42",
         "--principal",
         "agent:sol/dev-42",
         "--candidate",
         sha,
         "--checkout",
         "/tmp/work",
         "--blocked",
         "needs correction",
         "--json"
       ]},
      {"manual_lane_review",
       Map.merge(common, %{
         "principal" => "agent:astra/review-42",
         "candidate" => sha,
         "verdict" => "correction",
         "notes" => "/tmp/notes.md"
       }),
       [
         "lane",
         "review",
         "ML-42",
         "--principal",
         "agent:astra/review-42",
         "--verdict",
         "correction",
         "--candidate",
         sha,
         "--notes",
         "/tmp/notes.md",
         "--json"
       ]}
    ]

    input = Path.join(root, "calls.jsonl")

    File.write!(
      input,
      Enum.map_join(calls, "\n", fn {name, args, _} -> JSON.encode!(call(name, args)) end) <> "\n"
    )

    responses = run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_LOG", log}])
    assert Enum.all?(responses, &(get_in(&1, ["result", "isError"]) == false))

    assert Enum.map(responses, &get_in(&1, ["result", "content", Access.at(0), "text"])) ==
             List.duplicate(~s({"ok":true}), length(calls))

    assert recorded_argv(log) == Enum.map(calls, &elem(&1, 2))

    schema_input = Path.join(root, "schema.jsonl")

    File.write!(
      schema_input,
      JSON.encode!(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"}) <> "\n"
    )

    [schema] = run(schema_input, [])

    for tool <- get_in(schema, ["result", "tools"]) do
      assert tool["inputSchema"]["additionalProperties"] == false

      if tool["name"] == "manual_lane_overview" do
        assert tool["inputSchema"]["required"] == []
        assert tool["inputSchema"]["properties"] == %{}
      else
        assert "ticket_id" in tool["inputSchema"]["required"]
        assert tool["inputSchema"]["properties"]["ticket_id"]["maxLength"] == 128
      end

      assert tool["description"] =~ "same-UID"
      assert tool["description"] =~ "partial commit"
      assert tool["description"] =~ "CLI output text is capped at 16 KiB"
    end

    integrated =
      Enum.find(get_in(schema, ["result", "tools"]), &(&1["name"] == "manual_lane_integrated"))

    assert Map.keys(integrated["inputSchema"]["properties"]) == ["ticket_id"]
    assert integrated["inputSchema"]["required"] == ["ticket_id"]

    log_tool = Enum.find(get_in(schema, ["result", "tools"]), &(&1["name"] == "manual_lane_log"))
    assert log_tool["inputSchema"]["required"] == ["ticket_id"]
    assert Map.keys(log_tool["inputSchema"]["properties"]) == ["ticket_id"]
  end

  test "tools/call accepts only object metadata without changing CLI arguments" do
    root = temp_root()
    {release, log} = fake_release(root)
    input = Path.join(root, "requests.jsonl")
    meta = %{"pi-mcp-adapter/toolCallId" => "call-42"}
    sha = String.duplicate("a", 40)

    status =
      call("manual_lane_status", %{"ticket_id" => "ML-PG-MANUAL-MCP-PREVIEW"})
      |> put_in(["params", "_meta"], meta)

    log_call =
      call("manual_lane_log", %{"ticket_id" => "ML-42"})
      |> put_in(["params", "_meta"], meta)

    admit =
      call("manual_lane_admit", %{
        "ticket_id" => "ML-42",
        "base_ref" => sha,
        "title" => "Short title",
        "scope" => ["lib/a.ex"],
        "acceptance" => ["criterion"]
      })
      |> put_in(["params", "_meta"], meta)

    invalid = [
      put_in(status, ["params", "unexpected"], true),
      put_in(status, ["params", "_meta"], "call-42"),
      put_in(admit, ["params", "_meta"], []),
      put_in(admit, ["params", "arguments", "scope"], ["../escape"])
    ]

    File.write!(
      input,
      Enum.map_join([status, log_call, admit | invalid], "\n", &JSON.encode!/1) <> "\n"
    )

    responses = run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_LOG", log}])

    assert length(responses) == 7
    assert Enum.all?(Enum.take(responses, 3), &(get_in(&1, ["result", "isError"]) == false))
    assert Enum.all?(Enum.drop(responses, 3), &(get_in(&1, ["error", "code"]) == -32602))

    assert recorded_argv(log) == [
             ~w(lane status ML-PG-MANUAL-MCP-PREVIEW --json),
             ~w(lane log ML-42 --json),
             [
               "lane",
               "admit",
               "ML-42",
               "--base-ref",
               sha,
               "--title",
               "Short title",
               "--scope",
               "lib/a.ex",
               "--acceptance",
               "criterion",
               "--json"
             ]
           ]
  end

  test "malformed tool arguments never invoke the CLI; refusal remains a tool error" do
    root = temp_root()
    {release, log} = fake_release(root)
    sha = String.duplicate("b", 40)

    good = %{
      "ticket_id" => "ML-42",
      "base_ref" => sha,
      "title" => "T",
      "scope" => ["lib/a.ex"],
      "acceptance" => ["criterion"]
    }

    cases = [
      call("manual_lane_status", %{"ticket_id" => "ML-42", "extra" => true}),
      call("manual_lane_integrated", %{}),
      call("manual_lane_integrated", %{"ticket_id" => "ML-42", "ref" => "other"}),
      call("manual_lane_integrated", %{"ticket_id" => "../unsafe"}),
      call("manual_lane_overview", %{"ticket_id" => "ML-42"}),
      put_in(call("manual_lane_overview", %{}), ["params", "arguments"], []),
      update_in(call("manual_lane_overview", %{}), ["params"], &Map.delete(&1, "arguments")),
      call("manual_lane_log", %{"ticket_id" => "../unsafe"}),
      call("manual_lane_log", %{"ticket_id" => "--help"}),
      call("manual_lane_log", %{"ticket_id" => 42}),
      call("manual_lane_log", %{"ticket_id" => "ML-" <> String.duplicate("A", 126)}),
      call("manual_lane_log", %{"ticket_id" => "ML-42", "extra" => true}),
      call("manual_lane_log", %{}),
      put_in(call("manual_lane_log", %{"ticket_id" => "ML-42"}), ["params", "_meta"], []),
      call("manual_lane_admit", Map.put(good, "scope", ["../escape"])),
      call("manual_lane_admit", Map.put(good, "acceptance", [])),
      call("manual_lane_admit", Map.put(good, "title", "bad\nline")),
      call("manual_lane_admit", Map.put(good, "title", "--unexpected")),
      call("manual_lane_admit", Map.delete(good, "acceptance")),
      call("manual_lane_admit", Map.put(good, "base_ref", "--help")),
      call("manual_lane_developer_packet", %{
        "ticket_id" => "ML-42",
        "principal" => "x",
        "out" => "relative"
      }),
      call("manual_lane_reviewer_packet", %{
        "ticket_id" => "ML-42",
        "principal" => "bad principal",
        "out" => "/tmp/p"
      }),
      call("manual_lane_submit", %{
        "ticket_id" => "ML-42",
        "principal" => "x",
        "candidate" => "not-a-sha",
        "checkout" => "/tmp/p"
      }),
      call("manual_lane_review", %{
        "ticket_id" => "ML-42",
        "principal" => "x",
        "candidate" => sha,
        "verdict" => "accept",
        "notes" => "/tmp/n"
      }),
      call("manual_lane_review", %{
        "ticket_id" => "ML-42",
        "principal" => "x",
        "candidate" => sha,
        "verdict" => "approved",
        "notes" => "/tmp/n",
        "override" => true
      }),
      put_in(
        call("manual_lane_status", %{"ticket_id" => "ML-42"}),
        ["params", "unexpected"],
        true
      ),
      Map.put(
        call("manual_lane_status", %{"ticket_id" => "ML-42"}),
        "id",
        String.duplicate("x", 129)
      )
    ]

    input = Path.join(root, "invalid.jsonl")

    File.write!(input, Enum.map_join(cases, "\n", &JSON.encode!/1) <> "\n")

    responses = run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_LOG", log}])

    assert Enum.map(responses, &get_in(&1, ["error", "code"])) ==
             List.duplicate(-32602, length(cases) - 1) ++ [-32600]

    refute File.exists?(log)

    File.write!(input, JSON.encode!(call("manual_lane_admit", good)) <> "\n")

    [refusal] =
      run(input, [
        {"FOUNDRY_RELEASE", release},
        {"FOUNDRY_MCP_LOG", log},
        {"FOUNDRY_MCP_FAIL", "1"}
      ])

    assert refusal["result"]["isError"] == true
    assert get_in(refusal, ["result", "content", Access.at(0), "text"]) == "refused"

    assert recorded_argv(log) == [
             [
               "lane",
               "admit",
               "ML-42",
               "--base-ref",
               sha,
               "--title",
               "T",
               "--scope",
               "lib/a.ex",
               "--acceptance",
               "criterion",
               "--json"
             ]
           ]
  end

  test "oversized valid read-only requests refuse before CLI and drain for next request" do
    root = temp_root()
    {release, log} = fake_release(root)
    input = Path.join(root, "requests.jsonl")

    calls = [
      {"manual_lane_status", %{"ticket_id" => "ML-42"}, ~w(lane status ML-42 --json)},
      {"manual_lane_integrated", %{"ticket_id" => "ML-42"}, ~w(lane integrated ML-42 --json)},
      {"manual_lane_overview", %{}, ~w(lane status --json)},
      {"manual_lane_log", %{"ticket_id" => "ML-42"}, ~w(lane log ML-42 --json)}
    ]

    for {tool, args, argv} <- calls do
      request = call(tool, args)
      oversized = JSON.encode!(request) <> String.duplicate(" ", 16_385)
      File.write!(input, oversized <> "\n" <> JSON.encode!(request) <> "\n")

      [refusal, recovered] = run(input, [{"FOUNDRY_RELEASE", release}, {"FOUNDRY_MCP_LOG", log}])
      assert refusal["error"]["code"] == -32600
      assert refusal["id"] == nil
      assert recovered["result"]["isError"] == false
      assert get_in(recovered, ["result", "content", Access.at(0), "text"]) == ~s({"ok":true})
      assert List.last(recorded_argv(log)) == argv
    end

    assert recorded_argv(log) == Enum.map(calls, &elem(&1, 2))
  end

  defp call(name, args),
    do: %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "tools/call",
      "params" => %{"name" => name, "arguments" => args}
    }

  defp fake_release(root) do
    release = Path.join(root, "fake-release")
    log = Path.join(root, "rpc.log")

    File.write!(
      release,
      "#!/bin/sh\nprintf '%s\\n' \"$2\" >> \"$FOUNDRY_MCP_LOG\"\nif [ \"${FOUNDRY_MCP_FAIL:-}\" = 1 ]; then echo refused; exit 1; fi\necho '{\"ok\":true}'\n"
    )

    File.chmod!(release, 0o755)
    {release, log}
  end

  defp recorded_argv(log) do
    log
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(fn rpc ->
      [_, payload] = Regex.run(~r/Foundry\.CLI\.RPC\.run\("([A-Za-z0-9_-]+)"\)/, rpc)
      payload |> Base.url_decode64!(padding: false) |> JSON.decode!() |> Map.fetch!("argv")
    end)
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
