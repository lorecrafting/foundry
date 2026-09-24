alias Foundry.DurableStore.Gateway

[path, boundary] = System.argv()
fault = if boundary == "before", do: {:halt, :before_commit}, else: {:halt, :after_commit}

build = fn command_id ->
  projection_key =
    "projection/" <>
      Base.url_encode64("kernel-v1", padding: false) <>
      "/" <> Base.url_encode64("ticket-" <> command_id, padding: false)

  command = %{
    "schema_version" => 1,
    "command_id" => command_id,
    "expected_revisions" => %{projection_key => "absent"},
    "type" => "enqueue",
    "target_ids" => %{},
    "payload" => %{}
  }

  projection = %{
    "namespace" => "kernel-v1",
    "entity_id" => "ticket-" <> command_id,
    "revision" => 0,
    "value" => %{}
  }

  proposal = %{
    schema_version: 1,
    result: %{schema_version: 1, disposition: "accepted", reason_code: nil},
    events: [
      %{
        schema_version: 1,
        event_id: "event-" <> command_id,
        type: "execution_observed",
        payload: %{"projection" => projection}
      }
    ],
    projections: [
      %{
        schema_version: 1,
        namespace: projection["namespace"],
        entity_id: projection["entity_id"],
        expected_revision: -1,
        revision: 0,
        last_event_id: "event-" <> command_id,
        value: %{}
      }
    ],
    intents: [
      %{
        schema_version: 1,
        effect_id: "effect-" <> command_id,
        request_digest:
          elem(
            Foundry.DurableStore.Encoding.semantic_digest(
              "foundry-effect-request-v1",
              %{"effect_id" => "effect-" <> command_id, "operation" => %{"operation" => "check"}}
            ),
            1
          ),
        status: "pending",
        value: %{"operation" => "check"}
      }
    ]
  }

  {command, proposal}
end

:ok = Gateway.initialize(path)
{:ok, baseline_gateway} = Gateway.start_link(path: path)
{baseline_command, baseline_proposal} = build.("crash-baseline")

{:ok, _result, :committed} =
  Gateway.transact(baseline_gateway, "fixture", baseline_command, baseline_proposal)

:ok = GenServer.stop(baseline_gateway)
{:ok, gateway} = Gateway.start_link(path: path, fault: fault)
{command, proposal} = build.("crash-" <> boundary)
Gateway.transact(gateway, "fixture", command, proposal)
System.halt(70)
