defmodule Foundry.CLI.RPCTest do
  use ExUnit.Case, async: true

  alias Foundry.CLI.RPC

  describe "decode/1" do
    test "round-trips literal strings without evaluating source-looking text" do
      source_looking = "literal " <> <<35>> <> "{1 + 1}"

      argv = [
        "lane",
        "admit",
        "T-1",
        "--base-ref",
        "main",
        "--title",
        "quote \" slash \\ newline\nUnicode प्रमाण #{source_looking}",
        "--scope",
        "lib/**",
        "--acceptance",
        ""
      ]

      assert {:ok, ^argv} = argv |> envelope() |> encode() |> RPC.decode()
      assert Enum.at(argv, 6) =~ source_looking
      refute Enum.at(argv, 6) =~ "literal 2"
    end

    test "accepts lane command shapes, the only dispatched ones" do
      commands = [
        ["lane", "status"],
        ["lane", "status", "T-1", "--json"],
        ["lane", "log"],
        ["lane", "recover", "--evidence", "no other lane process"],
        ["lane", "packet", "T-1", "--role", "developer", "--principal", "p"],
        ["lane", "admit", "T-1", "--acceptance", "a", "--acceptance", "b"]
      ]

      Enum.each(commands, fn argv ->
        assert {:ok, ^argv} = argv |> envelope() |> encode() |> RPC.decode()
      end)
    end

    test "rejects malformed and non-canonical encodings" do
      assert RPC.decode(nil) == {:error, :invalid_encoding}
      assert RPC.decode("") == {:error, :invalid_encoding}
      assert RPC.decode("not+url/safe=") == {:error, :invalid_encoding}

      canonical = encode(envelope(["ticket", "list"]))
      assert RPC.decode(canonical <> "=") == {:error, :invalid_encoding}
      assert RPC.decode(encode_bytes("{")) == {:error, :invalid_json}
      assert RPC.decode(encode_bytes(<<255>>)) == {:error, :invalid_utf8}
    end

    test "rejects invalid envelope and argv values" do
      invalid = [
        {%{"version" => 2, "argv" => ["ticket", "list"]}, :invalid_envelope},
        {%{"version" => 1}, :invalid_envelope},
        {%{"version" => 1, "argv" => ["ticket", "list"], "extra" => true}, :invalid_envelope},
        {%{"version" => 1, "argv" => "ticket list"}, :invalid_argv},
        {%{"version" => 1, "argv" => ["ticket", 1]}, :invalid_argv},
        {%{"version" => 1, "argv" => ["ticket", "status", "bad" <> <<0>>]}, :nul_byte}
      ]

      Enum.each(invalid, fn {value, reason} ->
        assert RPC.decode(encode(value)) == {:error, reason}
      end)
    end

    test "rejects duplicate envelope keys in either order and escaped spelling" do
      duplicate_payloads = [
        ~S({"version":1,"version":2,"argv":["ticket","list"]}),
        ~S({"version":2,"version":1,"argv":["ticket","list"]}),
        ~S({"version":1,"argv":["ticket","list"],"argv":["unknown"]}),
        ~S({"version":1,"argv":["unknown"],"argv":["ticket","list"]}),
        ~S({"version":1,"\u0076ersion":1,"argv":["ticket","list"]}),
        ~S({"version":1,"argv":["ticket","list"],"\u0061rgv":["unknown"]})
      ]

      Enum.each(duplicate_payloads, fn payload ->
        assert RPC.decode(encode_bytes(payload)) == {:error, :duplicate_json_key}
      end)
    end

    test "rejects duplicate keys in nested adversarial objects" do
      duplicate_payloads = [
        ~S({"version":1,"argv":["ticket","list"],"extra":{"x":1,"x":2}}),
        ~S({"version":1,"argv":["ticket","list"],"extra":{"x":1,"\u0078":2}}),
        ~S({"version":1,"argv":[{"command":"ticket","command":"unknown"}]})
      ]

      Enum.each(duplicate_payloads, fn payload ->
        assert RPC.decode(encode_bytes(payload)) == {:error, :duplicate_json_key}
      end)
    end

    test "rejects unknown commands, subcommands, options and shapes" do
      # The retired legacy CLI shapes are refused like any other unknown shape.
      legacy = [
        ["handoff", "submit", "TASK-1", "--handoff-path", "/tmp/handoff.json"],
        ["review", "submit", "TASK-1", "--review-path", "/tmp/review.json"],
        ["ticket", "create", "--title", "title", "--priority", "P0"],
        ["ticket", "status", "TASK-1"],
        ["ticket", "list"],
        ["ticket", "integrate", "TASK-1"]
      ]

      lane = [
        ["lane"],
        ["lane", "launch", "T-1"],
        ["lane", "admit"],
        ["lane", "status", "--title", "x"],
        ["lane", "packet", "T-1", "--role", "a", "--role", "b"]
      ]

      invalid = [
        [],
        ["health"],
        ["ticket", "wat"],
        ["ticket", "unblock", "TASK-1"],
        ["ticket", "status"],
        ["ticket", "list", "extra"],
        ["handoff", "block", "TASK-1", "--reason"],
        ["handoff", "submit", "TASK-1", "--wrong", "path"],
        ["review", "submit", "TASK-1", "--review-path", "path", "extra"],
        ["ticket", "create", "--title", "title", "--priority", "PX"],
        ["ticket", "create", "--title", "title", "--priority", "P0", "--unknown", "x"],
        ["ticket", "create", "--title", "title", "--priority", "P0", "--scope"],
        [
          "ticket",
          "create",
          "--title",
          "title",
          "--priority",
          "P0",
          "--scope",
          "one",
          "--scope",
          "two"
        ]
      ]

      Enum.each(invalid ++ legacy ++ lane, fn argv ->
        assert RPC.decode(encode(envelope(argv))) == {:error, :unknown_command_shape}
      end)
    end

    test "rejects decoded and encoded payloads above the limit" do
      oversized = String.duplicate("x", 65_537)
      assert RPC.decode(encode_bytes(oversized)) == {:error, :payload_too_large}
      assert RPC.decode(String.duplicate("A", 87_383)) == {:error, :payload_too_large}
    end
  end

  test "run/1 reports transport rejection explicitly" do
    encoded = encode(envelope(["unknown"]))

    assert_raise ArgumentError, "invalid RPC payload: unknown_command_shape", fn ->
      RPC.run(encoded)
    end
  end

  defp envelope(argv), do: %{"version" => 1, "argv" => argv}

  defp encode(value) do
    value
    |> :json.encode()
    |> IO.iodata_to_binary()
    |> encode_bytes()
  end

  defp encode_bytes(bytes), do: Base.url_encode64(bytes, padding: false)
end
