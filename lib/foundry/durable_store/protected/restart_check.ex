defmodule Foundry.DurableStore.Protected.RestartCheck do
  @moduledoc false

  alias Foundry.DurableStore.{Database, Encoding, TransitionPlan}

  # Reopen-ready invariant: Operations writes states validated by RestartCheck and TransitionReplay.
  import Foundry.DurableStore.Protected.Rows
  import Foundry.DurableStore.Protected.Guards
  import Foundry.DurableStore.Protected.TransitionReplay

  @dimensions Foundry.DurableStore.Protected.Guards.dimensions()

  @doc false
  def validate(conn) do
    with :ok <- validate_blob_rows(conn, "root_commands", "result"),
         :ok <- validate_blob_rows(conn, "authenticated_inboxes", "state"),
         :ok <- validate_blob_rows(conn, "authenticated_inbox_items", "item"),
         :ok <- validate_blob_rows(conn, "root_policies", "state"),
         :ok <- validate_blob_rows(conn, "root_policy_history", "state"),
         :ok <- validate_blob_rows(conn, "root_controls", "state"),
         :ok <- validate_blob_rows(conn, "root_control_history", "state"),
         :ok <- validate_blob_rows(conn, "root_ledgers", "state"),
         :ok <- validate_blob_rows(conn, "root_reservations", "state"),
         :ok <- validate_blob_rows(conn, "root_effects", "state"),
         :ok <- validate_blob_rows(conn, "root_claims", "state"),
         :ok <- validate_blob_rows(conn, "root_receipts", "state"),
         :ok <- validate_blob_rows(conn, "root_leases", "state"),
         :ok <- validate_blob_rows(conn, "root_pointers", "state"),
         :ok <- validate_blob_rows(conn, "root_infrastructure_settlements", "state"),
         :ok <- validate_blob_rows(conn, "root_attempt_closures", "state"),
         :ok <- validate_attempt_closures(conn),
         :ok <- validate_atomic_bundle_rows(conn),
         :ok <- validate_root_commands(conn),
         :ok <- validate_simple_history(conn),
         :ok <- validate_root_pointers(conn),
         :ok <- validate_inboxes(conn),
         :ok <- validate_ledgers(conn),
         :ok <- validate_ledger_tree(conn),
         :ok <- validate_reservations(conn),
         :ok <- validate_state_bindings(conn),
         :ok <- validate_effect_relations(conn),
         :ok <- validate_semantic_relations(conn),
         :ok <- validate_authority_command_provenance(conn) do
      :ok
    end
  end

  defp validate_root_commands(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT seq, command_id, actor_id, request_digest, canonical_request, operation, disposition, reason_code, result FROM root_commands ORDER BY seq"
           ) do
      Enum.reduce_while(rows, :ok, fn
        [
          sequence,
          command_id,
          actor_id,
          digest,
          request_bytes,
          operation,
          disposition,
          reason,
          result_bytes
        ],
        :ok ->
          with {:ok, request_envelope} <- decode(request_bytes),
               ^actor_id <- request_envelope["actor_id"],
               %{"command_id" => ^command_id, "operation" => %{"type" => ^operation}} = request <-
                 request_envelope["request"],
               {:ok, ^digest} <- request_digest(actor_id, request),
               {:ok, result} <- decode(result_bytes),
               ^command_id <- result["command_id"],
               ^sequence <- result["command_sequence"],
               ^disposition <- result["disposition"],
               ^reason <- result["reason_code"] do
            {:cont, :ok}
          else
            _ -> {:halt, {:error, {:protected_corrupt, "root_commands", command_id}}}
          end
      end)
    end
  end

  defp validate_simple_history(conn) do
    Enum.reduce_while(
      [
        {"root_policies", "root_policy_history", "policy_id"},
        {"root_controls", "root_control_history", "control_id"}
      ],
      :ok,
      fn {head_table, history_table, id_column}, :ok ->
        sql =
          "SELECT h.#{id_column}, h.revision, h.prior_revision, h.command_id, h.state, c.canonical_request, c.result FROM #{history_table} h JOIN root_commands c ON c.command_id = h.command_id ORDER BY h.#{id_column}, h.revision"

        case Database.query(conn, sql) do
          {:ok, rows} ->
            with :ok <- validate_history_rows(rows, id_column, history_table),
                 {:ok, heads} <-
                   Database.query(
                     conn,
                     "SELECT #{id_column}, revision, state FROM #{head_table} ORDER BY #{id_column}"
                   ),
                 true <-
                   history_heads(rows) ==
                     Map.new(heads, fn [id, rev, state] -> {id, {rev, state}} end) do
              {:cont, :ok}
            else
              _ -> {:halt, {:error, {:protected_corrupt, history_table, :lineage}}}
            end

          {:error, _reason} = error ->
            {:halt, error}
        end
      end
    )
  end

  defp validate_history_rows(rows, id_column, _table) do
    type = if id_column == "policy_id", do: "set_policy", else: "set_control"

    Enum.reduce_while(rows, {:ok, %{}}, fn
      [id, revision, prior, command_id, state_bytes, request_bytes, result_bytes], {:ok, seen} ->
        expected_revision = Map.get(seen, id, 0)

        with true <- revision == expected_revision,
             true <- (revision == 0 and is_nil(prior)) or prior == revision - 1,
             {:ok, state} <- decode(state_bytes),
             true <- state[id_column] == id and state["revision"] == revision,
             {:ok, envelope} <- decode(request_bytes),
             %{"request" => request} <- envelope,
             %{"command_id" => ^command_id, "operation" => operation} <- request,
             ^type <- operation["type"],
             ^id <- operation[id_column],
             true <- operation["value"] == state["value"],
             {:ok, result} <- decode(result_bytes),
             "accepted" <- result["disposition"] do
          {:cont, {:ok, Map.put(seen, id, revision + 1)}}
        else
          _ -> {:halt, {:error, :invalid_history_provenance}}
        end
    end)
    |> case do
      {:ok, _seen} -> :ok
      error -> error
    end
  end

  defp history_heads(rows) do
    Enum.reduce(rows, %{}, fn [id, revision, _prior, _command, state | _], acc ->
      Map.put(acc, id, {revision, state})
    end)
  end

  defp validate_root_pointers(conn) do
    expected =
      MapSet.new(~w(accepted_source selected_deployment healthy_build), fn kind ->
        {kind, "absent", 0,
         %{
           "schema_version" => 1,
           "pointer_kind" => kind,
           "producer_status" => "absent",
           "revision" => 0,
           "value" => nil
         }}
      end)

    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT pointer_kind, producer_status, revision, state FROM root_pointers ORDER BY pointer_kind"
           ) do
      actual =
        Enum.reduce_while(rows, {:ok, MapSet.new()}, fn [kind, status, revision, bytes],
                                                        {:ok, acc} ->
          case decode(bytes) do
            {:ok, state} -> {:cont, {:ok, MapSet.put(acc, {kind, status, revision, state})}}
            _ -> {:halt, {:error, :invalid_pointer}}
          end
        end)

      case actual do
        {:ok, ^expected} -> :ok
        _ -> {:error, {:protected_corrupt, "root_pointers", :unauthorized_producer}}
      end
    end
  end

  defp validate_blob_rows(conn, table, column) do
    with {:ok, rows} <- Database.query(conn, "SELECT #{column} FROM #{table}") do
      Enum.reduce_while(rows, :ok, fn [bytes], :ok ->
        case decode(bytes) do
          {:ok, value} ->
            case encode(value) do
              {:ok, ^bytes} -> {:cont, :ok}
              _ -> {:halt, {:error, {:protected_corrupt, table, :noncanonical_blob}}}
            end

          _ ->
            {:halt, {:error, {:protected_corrupt, table, :invalid_blob}}}
        end
      end)
    end
  end

  defp validate_atomic_bundle_rows(conn) do
    with {:ok, bundles} <-
           Database.query(
             conn,
             "SELECT b.command_id, b.actor_id, b.request_digest, b.schema_version, b.disposition, b.reason_code, b.canonical_envelope, b.result, c.actor_id, c.request_digest, i.canonical_request, r.result " <>
               "FROM atomic_bundles b JOIN commands c ON c.command_id = b.command_id JOIN inputs i ON i.input_id = c.input_id JOIN command_results r ON r.command_id = c.command_id ORDER BY b.command_id"
           ),
         :ok <- validate_bundles(conn, bundles),
         {:ok, operations} <-
           Database.query(
             conn,
             "SELECT owner_kind, owner_id, ordinal, operation_kind, operation_type, request, result FROM durable_operations ORDER BY owner_kind, owner_id, ordinal"
           ),
         :ok <- validate_durable_operations(conn, operations),
         {:ok, settlements} <-
           Database.query(
             conn,
             "SELECT effect_id, claim_id, receipt_id, role, work_owner, infrastructure_generation, predecessor_effect_id, failure_class, ordinal, state FROM root_infrastructure_settlements ORDER BY effect_id"
           ) do
      validate_infrastructure_settlements(conn, settlements)
    end
  end

  # A closure row's columns must agree with the fact it stores.
  defp validate_attempt_closures(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT ticket_id, attempt_id, scope, state FROM root_attempt_closures"
           ) do
      Enum.reduce_while(rows, :ok, fn [ticket_id, attempt_id, scope, bytes], :ok ->
        case decode(bytes) do
          {:ok,
           %{
             "ticket_id" => ^ticket_id,
             "attempt_id" => ^attempt_id,
             "scope" => ^scope,
             "schema_version" => 1
           }} ->
            {:cont, :ok}

          _ ->
            {:halt, {:error, {:protected_corrupt, "root_attempt_closures", ticket_id}}}
        end
      end)
    end
  end

  defp validate_bundles(conn, rows) do
    Enum.reduce_while(rows, :ok, fn
      [
        id,
        actor,
        digest,
        2,
        disposition,
        reason,
        envelope_bytes,
        result_bytes,
        domain_actor,
        domain_digest,
        domain_request_bytes,
        domain_result_bytes
      ],
      :ok ->
        with {:ok, envelope} <- decode(envelope_bytes),
             true <- is_map(envelope),
             true <- is_map(envelope["command"]),
             2 <- envelope["schema_version"],
             ^id <- get_in(envelope, ["command", "command_id"]),
             ^actor <- envelope["actor_id"],
             ^actor <- domain_actor,
             {:ok, ^digest} <-
               Encoding.semantic_digest("foundry-atomic-bundle-v2", envelope),
             {:ok, domain_request} <- decode(domain_request_bytes),
             true <- is_map(domain_request),
             ^actor <- domain_request["actor_id"],
             true <- domain_request["command"] == envelope["command"],
             {:ok, expected_domain_bytes} <- Encoding.canonical(domain_request),
             true <- Encoding.digest(expected_domain_bytes) == domain_digest,
             {:ok, result} <- decode(result_bytes),
             true <- is_map(result),
             true <-
               Map.keys(result) |> Enum.sort() ==
                 ~w(command_id committed_seq disposition domain_result operations reason_code schema_version selected_discriminator),
             {:ok, domain_result} <- decode(domain_result_bytes),
             true <- is_map(domain_result),
             ^id <- result["command_id"],
             ^disposition <- result["disposition"],
             ^reason <- result["reason_code"],
             true <- result["domain_result"] == domain_result,
             :ok <- validate_bundle_operations(conn, id, envelope, result) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "atomic_bundles", id}}}
        end

      row, :ok ->
        {:halt, {:error, {:protected_corrupt, "atomic_bundles", inspect(row)}}}
    end)
  end

  defp validate_bundle_operations(conn, command_id, envelope, result) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT ordinal, operation_kind, operation_type, request, result FROM durable_operations WHERE owner_kind = 'bundle_v2' AND owner_id = ? ORDER BY ordinal",
             [command_id]
           ),
         operations when is_list(operations) <- envelope["operations"],
         operation_results when is_list(operation_results) <- result["operations"],
         true <- length(operation_results) == length(operations),
         expected_count <- length(operations) + 1,
         true <- length(rows) == expected_count,
         true <- row_ordinals(rows) == Enum.to_list(0..(expected_count - 1)//1),
         {protected_rows, [domain_row]} <- Enum.split(rows, expected_count - 1),
         {:ok, digest} <-
           Encoding.semantic_digest("foundry-atomic-bundle-v2", envelope),
         true <-
           Enum.zip([operations, operation_results, protected_rows])
           |> Enum.all?(fn tuple ->
             valid_bundle_protected_row?(conn, digest, result, tuple)
           end),
         true <- valid_bundle_domain_row?(domain_row, envelope, result),
         true <- valid_bundle_plan_binding?(conn, envelope, result) do
      :ok
    else
      _ -> {:error, :invalid_bundle_operation_binding}
    end
  end

  # Revalidates a plan-bound commit by reconstructing it.
  #
  # Comparing events alone is sufficient, but only because Authority's content validation
  # runs ahead of this in the same read: projection_matches_event?/2 ties each stored
  # projection to its carrier event's payload, and validate_reconstruction/2 rebuilds all
  # projections from events and compares. Pinning the events therefore pins the
  # projections transitively. If those checks were ever reordered after this one, a
  # projection comparison would have to be added here. Re-running the binding against
  # the original plan, the recorded discriminator and the persisted protected outcomes
  # must reproduce the committed events exactly. That proves those events could only have
  # come from that plan, those results and that discriminator, and it subsumes field-level
  # comparison rather than enumerating checks that need extending whenever a slot is added.
  #
  # The recorded discriminator is reconstructed from retained policy history, not trusted.
  # Trusting it left a hole: a store whose discriminator, events and projection were all
  # tampered coherently revalidated as valid, because the recorded value was the only free
  # input and nothing else read it. Recomputation uses
  # infrastructure_discriminator_at_revision/3, which reads the policy at the effect's
  # recorded revision rather than the head row, so a later policy revision does not turn a
  # valid historical commit into a corruption report.
  defp valid_bundle_plan_binding?(conn, envelope, result) do
    case envelope["plan"] do
      nil -> true
      plan -> valid_plan_binding?(conn, plan, envelope, result)
    end
  end

  # A bundle that committed no domain carriers has no binding to revalidate.
  defp valid_plan_binding?(_conn, _plan, _envelope, %{"disposition" => disposition})
       when disposition != "accepted",
       do: true

  defp valid_plan_binding?(conn, plan, envelope, result) do
    with discriminator when is_binary(discriminator) <- result["selected_discriminator"],
         staged when is_list(staged) <- result["operations"],
         :ok <- recorded_discriminator_reconstructs?(conn, plan, staged, discriminator),
         {:ok, proposal} <- TransitionPlan.bind(plan, discriminator, staged),
         {:ok, committed} <- committed_bundle_events(conn, envelope["command"]["command_id"]) do
      proposal["events"] == committed
    else
      _ -> false
    end
  end

  # An unconditional plan has one alternative and derives nothing, so the only value that
  # reconstructs is "unconditional" itself.
  defp recorded_discriminator_reconstructs?(
         _conn,
         %{"discriminator_kind" => "unconditional_v1"},
         _staged,
         recorded
       ) do
    if recorded == "unconditional",
      do: :ok,
      else: {:error, :discriminator_does_not_reconstruct}
  end

  defp recorded_discriminator_reconstructs?(conn, plan, staged, recorded) do
    with {:ok, settlement} <- bound_settlement_fact(plan, staged),
         {:ok, ^recorded} <-
           infrastructure_discriminator_at_revision(conn, settlement["effect_id"], settlement) do
      :ok
    else
      _ -> {:error, :discriminator_does_not_reconstruct}
    end
  end

  # Mirrors Gateway's ordinal resolution: the settlement is the one the plan's own
  # settlement binding names, not whichever one happens to be unique.
  defp bound_settlement_fact(plan, staged) do
    case Enum.filter(plan["bindings"], &(&1["output_kind"] == "nonstart_settlement_v1")) do
      [binding] ->
        settlement =
          staged
          |> Enum.find(%{}, &(&1["ordinal"] == binding["operation_ordinal"]))
          |> get_in(["result", "facts", "infrastructure_settlement"])

        if is_map(settlement), do: {:ok, settlement}, else: {:error, :settlement_unavailable}

      _ ->
        {:error, :settlement_unavailable}
    end
  end

  defp committed_bundle_events(conn, command_id) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT event FROM events WHERE command_id = ? ORDER BY seq",
             [command_id]
           ),
         decoded <- Enum.map(rows, fn [bytes] -> decode(bytes) end),
         true <- Enum.all?(decoded, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(decoded, fn {:ok, event} -> event end)}
    else
      _ -> {:error, :unreadable_committed_events}
    end
  end

  defp row_ordinals(rows) do
    Enum.map(rows, fn
      [ordinal | _] when is_integer(ordinal) -> ordinal
      _ -> :invalid
    end)
  end

  defp valid_bundle_protected_row?(
         conn,
         digest,
         bundle_result,
         {operation, operation_result, row}
       ) do
    case row do
      [ordinal, "protected", type, request_bytes, stored_bytes] ->
        expected_id = "atomic-v2/#{digest}/#{ordinal}"

        with true <- is_map(bundle_result),
             true <- is_map(operation),
             true <- is_map(operation_result),
             true <- operation["ordinal"] == ordinal,
             true <- operation["operation_type"] == type,
             true <-
               Map.keys(operation_result) |> Enum.sort() ==
                 ~w(execution_status operation_kind operation_type ordinal result),
             true <- operation_result["ordinal"] == ordinal,
             true <- operation_result["operation_kind"] == "protected",
             true <- operation_result["operation_type"] == type,
             status when status in ["committed", "duplicate", "rolled_back", "unexecuted"] <-
               operation_result["execution_status"],
             {:ok, request} <- decode(request_bytes),
             true <-
               Map.keys(request) |> Enum.sort() ==
                 ~w(command_id expected_revisions operation schema_version),
             ^expected_id <- request["command_id"],
             true <- request["operation"] == operation["operation"],
             {:ok, stored} <- decode(stored_bytes),
             true <-
               Map.keys(stored) |> Enum.sort() ==
                 ~w(execution_status operation_result schema_version),
             1 <- stored["schema_version"],
             ^status <- stored["execution_status"],
             true <- stored["operation_result"] == operation_result["result"],
             true <- valid_execution_status?(bundle_result["disposition"], status),
             true <- valid_operation_reason?(bundle_result, status, operation_result["result"]),
             true <-
               valid_protected_outcome_provenance(
                 conn,
                 status,
                 expected_id,
                 type,
                 request_bytes,
                 operation_result["result"]
               ) do
          true
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  defp valid_execution_status?("accepted", "committed"), do: true
  defp valid_execution_status?("quarantined", "committed"), do: true

  defp valid_execution_status?("rejected", status) when status in ["rolled_back", "unexecuted"],
    do: true

  defp valid_execution_status?("rejected", "duplicate"), do: true

  defp valid_execution_status?(_disposition, _status), do: false

  defp valid_operation_reason?(_bundle, "committed", _result), do: true

  defp valid_operation_reason?(bundle, status, result)
       when is_map(bundle) and is_map(result) and
              status in ["duplicate", "rolled_back", "unexecuted"],
       do: result["reason_code"] == bundle["reason_code"]

  defp valid_operation_reason?(_bundle, _status, _result), do: false

  defp valid_protected_outcome_provenance(
         conn,
         "committed",
         command_id,
         type,
         request_bytes,
         operation_result
       ) do
    with {:ok, request} <- decode(request_bytes),
         true <- is_map(request),
         true <- is_map(operation_result),
         {:ok, [[^type, root_request_bytes, root_result_bytes]]} <-
           Database.query(
             conn,
             "SELECT operation, canonical_request, result FROM root_commands WHERE command_id = ?",
             [command_id]
           ),
         {:ok, root_request} <- decode(root_request_bytes),
         {:ok, root_result} <- decode(root_result_bytes),
         true <- is_map(root_request),
         true <- is_map(root_result),
         true <- root_request["request"] == request,
         true <- root_result == without_settlement_carrier(operation_result),
         true <-
           valid_committed_settlement_carrier(conn, request, root_result, operation_result) do
      true
    else
      _ -> false
    end
  end

  defp valid_protected_outcome_provenance(
         conn,
         "rolled_back",
         command_id,
         _type,
         _request,
         result
       ) do
    with true <- is_map(result),
         "rolled_back" <- result["disposition"],
         ^command_id <- result["command_id"],
         true <-
           Map.keys(result) |> Enum.sort() ==
             ~w(command_id disposition facts reason_code schema_version),
         true <- result["facts"] == %{},
         {:ok, [[0]]} <-
           Database.query(conn, "SELECT count(*) FROM root_commands WHERE command_id = ?", [
             command_id
           ]) do
      true
    else
      _ -> false
    end
  end

  defp valid_protected_outcome_provenance(
         conn,
         "duplicate",
         command_id,
         _type,
         request_bytes,
         result
       ) do
    with true <- is_map(result),
         facts when is_map(facts) <- result["facts"],
         settlement when is_map(settlement) <- facts["infrastructure_settlement"],
         {:ok, request} <- decode(request_bytes),
         true <- is_map(request),
         "duplicate" <- result["disposition"],
         ^command_id <- result["command_id"],
         true <-
           Map.keys(result) |> Enum.sort() ==
             ~w(command_id disposition facts reason_code schema_version),
         true <- Map.keys(facts) == ["infrastructure_settlement"],
         true <- valid_duplicate_settlement_carrier(conn, request, settlement),
         {:ok, [[0]]} <-
           Database.query(conn, "SELECT count(*) FROM root_commands WHERE command_id = ?", [
             command_id
           ]) do
      true
    else
      _ -> false
    end
  end

  defp valid_protected_outcome_provenance(conn, "unexecuted", command_id, _type, _request, result) do
    with true <- is_map(result),
         "unexecuted" <- result["disposition"],
         ^command_id <- result["command_id"],
         true <-
           Map.keys(result) |> Enum.sort() ==
             ~w(command_id disposition facts reason_code schema_version),
         true <- result["facts"] == %{},
         {:ok, [[0]]} <-
           Database.query(conn, "SELECT count(*) FROM root_commands WHERE command_id = ?", [
             command_id
           ]) do
      true
    else
      _ -> false
    end
  end

  defp valid_protected_outcome_provenance(
         _conn,
         _status,
         _command_id,
         _type,
         _request,
         _result
       ),
       do: false

  defp without_settlement_carrier(%{"facts" => facts} = result) when is_map(facts),
    do: %{result | "facts" => Map.delete(facts, "infrastructure_settlement")}

  defp without_settlement_carrier(result), do: result

  defp valid_committed_settlement_carrier(conn, request, root_result, operation_result) do
    operation = request["operation"]
    root_facts = root_result["facts"]
    operation_facts = operation_result["facts"]

    with true <- is_map(operation),
         true <- is_map(root_facts),
         true <- is_map(operation_facts) do
      receipt = root_facts["receipt"]
      settlement = operation_facts["infrastructure_settlement"]
      settlement_present? = Map.has_key?(operation_facts, "infrastructure_settlement")

      requires_settlement? =
        operation["type"] == "settle_claim" and is_map(receipt) and
          receipt["outcome"] == "non_started"

      cond do
        requires_settlement? and settlement_present? and is_map(settlement) ->
          valid_authoritative_settlement(conn, operation, root_facts, settlement)

        requires_settlement? ->
          false

        settlement_present? ->
          false

        true ->
          true
      end
    else
      _ -> false
    end
  end

  defp valid_authoritative_settlement(conn, operation, root_facts, settlement) do
    effect = root_facts["effect"]
    claim = root_facts["claim"]
    receipt = root_facts["receipt"]
    receipt_payload = if(is_map(receipt), do: receipt["payload"], else: nil)

    with true <- valid_settlement_shape?(settlement),
         true <- is_map(effect) and is_map(claim) and is_map(receipt),
         true <- is_map(receipt_payload),
         true <- settlement["effect_id"] == effect["effect_id"],
         true <- settlement["claim_id"] == claim["claim_id"],
         true <- settlement["receipt_id"] == receipt["receipt_id"],
         true <- settlement["role"] == effect["role"],
         true <- settlement["work_owner"] == effect["assignment_id"],
         true <- settlement["infrastructure_generation"] == effect["phase_generation"],
         true <- settlement["predecessor_effect_id"] == effect["predecessor_effect_id"],
         true <- settlement["claim_id"] == operation["claim_id"],
         true <- settlement["receipt_id"] == operation["receipt_id"],
         true <- receipt["request_id"] == operation["request_id"],
         true <- receipt["outcome"] == "non_started",
         true <- settlement["failure_class"] == receipt_payload["failure_class"],
         {:ok, settlement_bytes} <- encode(settlement),
         {:ok, [[^settlement_bytes]]} <-
           Database.query(
             conn,
             "SELECT state FROM root_infrastructure_settlements WHERE effect_id = ? AND claim_id = ? AND receipt_id = ?",
             [settlement["effect_id"], settlement["claim_id"], settlement["receipt_id"]]
           ) do
      true
    else
      _ -> false
    end
  end

  defp valid_duplicate_settlement_carrier(conn, request, settlement) do
    operation = request["operation"]
    payload = if(is_map(operation), do: operation["payload"], else: nil)

    with true <- is_map(operation),
         true <- is_map(payload),
         "settle_claim" <- operation["type"],
         "non_started" <- operation["outcome"],
         true <- valid_settlement_shape?(settlement),
         true <- settlement["claim_id"] == operation["claim_id"],
         true <- settlement["receipt_id"] == operation["receipt_id"],
         true <- settlement["failure_class"] == payload["failure_class"],
         {:ok, settlement_bytes} <- encode(settlement),
         {:ok, [[^settlement_bytes]]} <-
           Database.query(
             conn,
             "SELECT state FROM root_infrastructure_settlements WHERE effect_id = ? AND claim_id = ? AND receipt_id = ?",
             [settlement["effect_id"], settlement["claim_id"], settlement["receipt_id"]]
           ) do
      true
    else
      _ -> false
    end
  end

  defp valid_settlement_shape?(settlement) when is_map(settlement) do
    Map.keys(settlement) |> Enum.sort() ==
      ~w(claim_id effect_id failure_class infrastructure_generation ordinal predecessor_effect_id receipt_id role schema_version work_owner) and
      settlement["schema_version"] == 1 and is_binary(settlement["effect_id"]) and
      is_binary(settlement["claim_id"]) and is_binary(settlement["receipt_id"]) and
      is_binary(settlement["role"]) and is_binary(settlement["work_owner"]) and
      is_integer(settlement["infrastructure_generation"]) and
      settlement["infrastructure_generation"] >= 0 and
      (is_nil(settlement["predecessor_effect_id"]) or
         is_binary(settlement["predecessor_effect_id"])) and
      is_binary(settlement["failure_class"]) and is_integer(settlement["ordinal"]) and
      settlement["ordinal"] > 0
  end

  defp valid_settlement_shape?(_settlement), do: false

  # Delegates to Gateway rather than mirroring it. A hand-copied rule would be correct
  # only while both sides happen to agree: add a third carrier, update one side, and a
  # legitimately committed bundle reads as :protected_corrupt on its next validation.
  #
  # This is deliberately unlike the TransitionPlan/Kernel.Plan duplication, which exists
  # because those are different trust tiers and root must never execute candidate code.
  # Gateway and ProtectedPrimitives are the same trust tier, so duplication here buys
  # nothing and costs a silent divergence.
  defp expected_bundle_domain_request(envelope),
    do: Foundry.DurableStore.Gateway.atomic_domain_request(envelope)

  defp valid_bundle_domain_row?(row, envelope, result) do
    case row do
      [ordinal, "domain", type, request_bytes, result_bytes] ->
        expected_ordinal = length(envelope["operations"])

        expected_status =
          if result["disposition"] == "accepted", do: "committed", else: "rejected"

        with true <- ordinal == expected_ordinal,
             true <- type == envelope["command"]["type"],
             {:ok, request} <- decode(request_bytes),
             true <- request == expected_bundle_domain_request(envelope),
             {:ok, stored} <- decode(result_bytes),
             true <-
               Map.keys(stored) |> Enum.sort() ==
                 ~w(execution_status operation_result schema_version),
             1 <- stored["schema_version"],
             ^expected_status <- stored["execution_status"],
             true <- stored["operation_result"] == result["domain_result"] do
          true
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  defp validate_durable_operations(conn, rows) do
    with :ok <- validate_domain_v1_operations(conn, rows),
         :ok <- validate_protected_v1_operations(conn, rows),
         true <-
           Enum.all?(rows, fn
             [owner, _id, ordinal, kind, type, request, result]
             when owner in ["domain_v1", "protected_v1", "bundle_v2"] and
                    is_integer(ordinal) and ordinal >= 0 and kind in ["domain", "protected"] and
                    is_binary(type) and is_binary(request) and is_binary(result) ->
               true

             _ ->
               false
           end) do
      :ok
    else
      _ -> {:error, {:protected_corrupt, "durable_operations", :invalid_history}}
    end
  end

  defp validate_domain_v1_operations(conn, rows) do
    actual =
      rows
      |> Enum.filter(&(Enum.at(&1, 0) == "domain_v1"))
      |> MapSet.new()

    with {:ok, expected_rows} <-
           Database.query(
             conn,
             "SELECT 'domain_v1', c.command_id, 0, 'domain', c.command_type, i.canonical_request, r.result " <>
               "FROM commands c JOIN inputs i ON i.input_id = c.input_id JOIN command_results r ON r.command_id = c.command_id " <>
               "LEFT JOIN atomic_bundles b ON b.command_id = c.command_id WHERE b.command_id IS NULL"
           ),
         true <- actual == MapSet.new(expected_rows) do
      :ok
    else
      _ -> {:error, :invalid_domain_v1_history}
    end
  end

  defp validate_protected_v1_operations(conn, rows) do
    actual =
      rows
      |> Enum.filter(&(Enum.at(&1, 0) == "protected_v1"))
      |> MapSet.new()

    with {:ok, expected_rows} <-
           Database.query(
             conn,
             "SELECT 'protected_v1', command_id, 0, 'protected', operation, canonical_request, result FROM root_commands " <>
               "WHERE command_id NOT LIKE 'atomic-v2/%'"
           ),
         true <- actual == MapSet.new(expected_rows),
         {:ok, [[orphan_atomic_roots]]} <-
           Database.query(
             conn,
             "SELECT count(*) FROM root_commands rc WHERE rc.command_id LIKE 'atomic-v2/%' AND NOT EXISTS (" <>
               "SELECT 1 FROM durable_operations d WHERE d.owner_kind = 'bundle_v2' AND d.operation_kind = 'protected' " <>
               "AND json_extract(CAST(d.request AS TEXT), '$.command_id') = rc.command_id)"
           ),
         true <- orphan_atomic_roots == 0 do
      :ok
    else
      _ -> {:error, :invalid_protected_v1_history}
    end
  end

  defp validate_infrastructure_settlements(conn, rows) do
    with {:ok, required_effects} <- required_settlement_effects(conn),
         true <- MapSet.new(Enum.map(rows, &hd/1)) == required_effects,
         :ok <- validate_settlement_rows(conn, rows),
         :ok <- validate_settlement_lineage(rows) do
      :ok
    else
      _ -> {:error, {:protected_corrupt, "root_infrastructure_settlements", :invalid_history}}
    end
  end

  defp required_settlement_effects(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT d.request, d.result FROM durable_operations d JOIN atomic_bundles b ON b.command_id = d.owner_id " <>
               "WHERE d.owner_kind = 'bundle_v2' AND d.operation_kind = 'protected' AND d.operation_type = 'settle_claim' AND b.disposition = 'accepted'"
           ) do
      Enum.reduce_while(rows, {:ok, MapSet.new()}, fn [request_bytes, result_bytes], {:ok, acc} ->
        with {:ok, request} <- decode(request_bytes),
             {:ok, stored} <- decode(result_bytes) do
          if get_in(request, ["operation", "outcome"]) == "non_started" and
               stored["execution_status"] == "committed" do
            case get_in(stored, ["operation_result", "facts", "effect", "effect_id"]) do
              effect_id when is_binary(effect_id) ->
                {:cont, {:ok, MapSet.put(acc, effect_id)}}

              _ ->
                {:halt, {:error, :invalid_settlement_carrier}}
            end
          else
            {:cont, {:ok, acc}}
          end
        else
          _ -> {:halt, {:error, :invalid_settlement_carrier}}
        end
      end)
    end
  end

  defp validate_settlement_rows(conn, rows) do
    Enum.reduce_while(rows, :ok, fn row, :ok ->
      case row do
        [
          effect_id,
          claim_id,
          receipt_id,
          role,
          owner,
          generation,
          predecessor,
          failure,
          ordinal,
          bytes
        ] ->
          with {:ok, [[effect_bytes]]} <-
                 Database.query(conn, "SELECT state FROM root_effects WHERE effect_id = ?", [
                   effect_id
                 ]),
               {:ok, [[claim_bytes]]} <-
                 Database.query(
                   conn,
                   "SELECT state FROM root_claims WHERE claim_id = ? AND effect_id = ?",
                   [claim_id, effect_id]
                 ),
               {:ok, [[receipt_bytes]]} <-
                 Database.query(
                   conn,
                   "SELECT state FROM root_receipts WHERE receipt_id = ? AND claim_id = ? AND outcome = 'non_started'",
                   [receipt_id, claim_id]
                 ),
               {:ok, effect} <- decode(effect_bytes),
               {:ok, claim} <- decode(claim_bytes),
               {:ok, receipt} <- decode(receipt_bytes),
               true <- claim["effect_id"] == effect_id,
               true <- receipt["claim_id"] == claim_id,
               failure_class when is_binary(failure_class) <-
                 get_in(receipt, ["payload", "failure_class"]),
               expected <- %{
                 "schema_version" => 1,
                 "effect_id" => effect_id,
                 "claim_id" => claim_id,
                 "receipt_id" => receipt_id,
                 "role" => effect["role"],
                 "work_owner" => effect["assignment_id"],
                 "infrastructure_generation" => effect["phase_generation"],
                 "predecessor_effect_id" => effect["predecessor_effect_id"],
                 "failure_class" => failure_class,
                 "ordinal" => ordinal
               },
               true <-
                 [role, owner, generation, predecessor, failure] ==
                   [
                     expected["role"],
                     expected["work_owner"],
                     expected["infrastructure_generation"],
                     expected["predecessor_effect_id"],
                     expected["failure_class"]
                   ],
               {:ok, ^bytes} <- encode(expected) do
            {:cont, :ok}
          else
            _ -> {:halt, {:error, :invalid_settlement_row}}
          end

        _ ->
          {:halt, {:error, :invalid_settlement_row}}
      end
    end)
  end

  defp validate_settlement_lineage(rows) do
    rows
    |> Enum.group_by(fn [_effect, _claim, _receipt, role, owner, generation | _] ->
      {role, owner, generation}
    end)
    |> Enum.reduce_while(:ok, fn {_identity, group}, :ok ->
      ordered = Enum.sort_by(group, &Enum.at(&1, 8))

      valid =
        Enum.with_index(ordered, 1)
        |> Enum.all?(fn {row, expected_ordinal} ->
          effect_id = Enum.at(row, 0)
          predecessor = Enum.at(row, 6)
          ordinal = Enum.at(row, 8)

          ordinal == expected_ordinal and
            if expected_ordinal == 1,
              do: is_nil(predecessor),
              else:
                predecessor == ordered |> Enum.at(expected_ordinal - 2) |> Enum.at(0) and
                  is_binary(effect_id)
        end)

      if valid, do: {:cont, :ok}, else: {:halt, {:error, :invalid_settlement_lineage}}
    end)
  end

  defp validate_inboxes(conn) do
    with {:ok, heads} <-
           Database.query(
             conn,
             "SELECT execution_id, last_sequence, sealed_sequence, state FROM authenticated_inboxes"
           ) do
      Enum.reduce_while(heads, :ok, fn [id, last, sealed, state_bytes], :ok ->
        with {:ok, items} <-
               Database.query(
                 conn,
                 "SELECT sequence, item_kind, disposition, item_digest, item FROM authenticated_inbox_items WHERE execution_id = ? ORDER BY sequence",
                 [id]
               ),
             true <- length(items) == last,
             true <- Enum.map(items, &hd/1) == Enum.to_list(1..last//1),
             true <- is_nil(sealed) or sealed <= last,
             :ok <- validate_inbox_items(id, sealed, items),
             {:ok, inbox} <- load_existing_inbox(conn, id),
             expected_state <- inbox_state(id, inbox),
             {:ok, ^expected_state} <- decode(state_bytes) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "authenticated_inboxes", id}}}
        end
      end)
    end
  end

  defp validate_inbox_items(execution_id, sealed, items) do
    Enum.reduce_while(items, :ok, fn [sequence, kind, disposition, digest, bytes], :ok ->
      with {:ok, item} <- decode(bytes),
           true <- item["execution_id"] == execution_id,
           true <- item["sequence"] == sequence,
           true <- item["item_kind"] == kind,
           true <- item["disposition"] == disposition,
           expected_disposition <-
             if(is_integer(sealed) and sequence > sealed, do: "late", else: "accepted"),
           true <- disposition == expected_disposition,
           {:ok, ^digest} <-
             Encoding.semantic_digest("foundry-authenticated-inbox-item-v1", %{
               "execution_id" => execution_id,
               "sequence" => sequence,
               "item_kind" => kind,
               "payload" => item["payload"]
             }) do
        {:cont, :ok}
      else
        _ -> {:halt, {:error, :invalid_inbox_item_provenance}}
      end
    end)
  end

  defp validate_ledgers(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT ledger_id, generation, parent_ledger_id, parent_generation, dimension, revision, status, authorized, available, held, consumed, delegated, retired, state FROM root_ledgers"
           ) do
      Enum.reduce_while(rows, :ok, fn row, :ok ->
        {ledger_row, [state_bytes]} = Enum.split(row, 13)
        ledger = ledger_from_row(ledger_row)

        with true <- conserved?(ledger) and ledger.dimension in @dimensions,
             {:ok, expected} <- encode(public_ledger(ledger)),
             ^expected <- state_bytes do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_ledgers", ledger.ledger_id}}}
        end
      end)
    end
  end

  defp validate_ledger_tree(conn) do
    with {:ok, parents} <-
           Database.query(
             conn,
             "SELECT p.ledger_id, p.generation, p.delegated, coalesce(sum(c.authorized), 0) FROM root_ledgers p LEFT JOIN root_ledgers c ON c.parent_ledger_id = p.ledger_id AND c.parent_generation = p.generation AND c.dimension = p.dimension GROUP BY p.ledger_id, p.generation, p.delegated"
           ) do
      case Enum.find(parents, fn [_id, _generation, delegated, child_authorized] ->
             delegated != child_authorized
           end) do
        nil ->
          :ok

        [id, generation | _rest] ->
          {:error, {:protected_corrupt, "root_ledgers", {id, generation, :tree_conservation}}}
      end
    end
  end

  defp validate_reservations(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT l.ledger_id, l.generation, coalesce(sum(CASE WHEN r.status IN ('reserved', 'issued_unknown') THEN r.units ELSE 0 END), 0), coalesce(sum(CASE WHEN r.status = 'consumed' THEN r.units ELSE 0 END), 0) FROM root_ledgers l LEFT JOIN root_reservations r ON r.ledger_id = l.ledger_id AND r.generation = l.generation GROUP BY l.ledger_id, l.generation"
           ) do
      Enum.reduce_while(rows, :ok, fn [id, generation, held, consumed], :ok ->
        case load_existing_ledger(conn, id, generation) do
          {:ok, ledger} when ledger.held == held and ledger.consumed == consumed -> {:cont, :ok}
          _ -> {:halt, {:error, {:protected_corrupt, "root_reservations", id}}}
        end
      end)
    end
  end

  defp validate_effect_relations(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT c.claim_id, c.effect_id, c.status, e.status FROM root_claims c JOIN root_effects e ON e.effect_id = c.effect_id"
           ) do
      if Enum.all?(rows, fn [_claim_id, _effect_id, claim_status, effect_status] ->
           claim_status == effect_status or
             {claim_status, effect_status} in [{"claimed", "claimed"}, {"issued", "issued"}]
         end),
         do: :ok,
         else: {:error, {:protected_corrupt, "root_claims", :state_mismatch}}
    end
  end

  defp validate_semantic_relations(conn) do
    with :ok <- validate_effect_authority_relations(conn),
         :ok <- validate_receipt_provenance(conn),
         :ok <- validate_request_ownership(conn) do
      :ok
    end
  end

  defp validate_authority_command_provenance(conn) do
    with :ok <- validate_ledger_result_provenance(conn),
         :ok <- validate_effect_command_provenance(conn),
         :ok <- validate_claim_command_provenance(conn),
         :ok <- validate_typed_transition_replay(conn),
         :ok <- validate_current_transition_provenance(conn),
         :ok <- validate_reservation_command_provenance(conn) do
      :ok
    end
  end

  defp validate_ledger_result_provenance(conn) do
    with {:ok, command_rows} <-
           Database.query(
             conn,
             "SELECT operation, canonical_request, result FROM root_commands WHERE disposition = 'accepted' AND operation IN ('grant_ledger', 'delegate_allocation', 'reset_generation') ORDER BY seq"
           ),
         {:ok, origins} <- ledger_creation_origins(conn, command_rows),
         {:ok, ledger_rows} <-
           Database.query(
             conn,
             "SELECT ledger_id, generation, parent_ledger_id, parent_generation, dimension, revision, status, authorized, available, held, consumed, delegated, retired FROM root_ledgers"
           ) do
      Enum.reduce_while(ledger_rows, :ok, fn row, :ok ->
        ledger = public_ledger(ledger_from_row(row))

        origin = Map.get(origins, {ledger["ledger_id"], ledger["generation"]})

        origin? =
          is_map(origin) and origin["dimension"] == ledger["dimension"] and
            origin["parent_ledger_id"] == ledger["parent_ledger_id"] and
            origin["parent_generation"] == ledger["parent_generation"] and
            ledger["authorized"] <= origin["authorized"]

        if origin?,
          do: {:cont, :ok},
          else: {:halt, {:error, {:protected_corrupt, "root_ledgers", :command_provenance}}}
      end)
    end
  end

  defp ledger_creation_origins(conn, rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn [type, request_bytes, result_bytes], {:ok, acc} ->
      with {:ok, %{"request" => %{"operation" => operation}}} <- decode(request_bytes),
           ^type <- operation["type"],
           {:ok, result} <- decode(result_bytes),
           {:ok, fact} <- ledger_creation_fact(conn, operation, result["facts"]),
           key <- {fact["ledger_id"], fact["generation"]},
           false <- Map.has_key?(acc, key) do
        {:cont, {:ok, Map.put(acc, key, fact)}}
      else
        _ -> {:halt, {:error, :invalid_ledger_command_provenance}}
      end
    end)
  end

  defp ledger_creation_fact(_conn, %{"type" => "grant_ledger"} = operation, facts) do
    validate_creation_ledger(
      facts["ledger"],
      operation["ledger_id"],
      operation["generation"],
      nil,
      nil,
      operation["dimension"],
      operation["units"]
    )
  end

  defp ledger_creation_fact(_conn, %{"type" => "delegate_allocation"} = operation, facts) do
    validate_creation_ledger(
      facts["child_ledger"],
      operation["child_ledger_id"],
      operation["child_generation"],
      operation["parent_ledger_id"],
      operation["parent_generation"],
      operation["dimension"],
      operation["units"]
    )
  end

  defp ledger_creation_fact(conn, %{"type" => "reset_generation"} = operation, facts) do
    with {:ok, old} <-
           load_existing_ledger(conn, operation["ledger_id"], operation["old_generation"]) do
      validate_creation_ledger(
        facts["new_generation"],
        operation["ledger_id"],
        operation["new_generation"],
        operation["parent_ledger_id"],
        operation["parent_generation"],
        old.dimension,
        operation["units"]
      )
    end
  end

  defp validate_creation_ledger(
         fact,
         ledger_id,
         generation,
         parent_id,
         parent_generation,
         dimension,
         units
       ) do
    with true <- is_map(fact),
         true <- fact["schema_version"] == 1,
         true <- fact["ledger_id"] == ledger_id and fact["generation"] == generation,
         true <- fact["parent_ledger_id"] == parent_id,
         true <- fact["parent_generation"] == parent_generation,
         true <- fact["dimension"] == dimension,
         true <- fact["revision"] == 0 and fact["status"] == "open",
         true <- fact["authorized"] == units and fact["available"] == units,
         true <-
           Enum.all?(~w(held consumed delegated retired), fn key -> fact[key] == 0 end) do
      {:ok, fact}
    else
      _ -> {:error, :invalid_ledger_creation_fact}
    end
  end

  defp validate_effect_command_provenance(conn) do
    with {:ok, command_rows} <-
           Database.query(
             conn,
             "SELECT actor_id, canonical_request, disposition FROM root_commands WHERE operation = 'create_effect' ORDER BY seq"
           ),
         {:ok, effect_rows} <- Database.query(conn, "SELECT effect_id FROM root_effects") do
      Enum.reduce_while(effect_rows, :ok, fn [id], :ok ->
        with {:ok, effect} <- load_effect(conn, id),
             [{actor, operation}] <-
               Enum.flat_map(command_rows, fn [actor, bytes, disposition] ->
                 with "accepted" <- disposition,
                      {:ok, %{"request" => %{"operation" => operation}}} <- decode(bytes),
                      ^id <- operation["effect_id"] do
                   [{actor, operation}]
                 else
                   _ -> []
                 end
               end),
             true <- actor == effect.issuer and effect.channel == "protected-gateway",
             {:ok, digest} <-
               Encoding.semantic_digest("foundry-effect-request-v1", %{
                 "effect_id" => operation["effect_id"],
                 "operation" => operation["operation"],
                 "scope" => operation["scope"],
                 "ticket_id" => operation["ticket_id"],
                 "attempt_id" => operation["attempt_id"],
                 "execution_id" => operation["execution_id"],
                 "request" => operation["request"]
               }),
             true <- digest == effect.request_digest,
             true <- effect.policy_id == operation["policy_id"],
             true <- effect.policy_revision == operation["policy_revision"],
             true <- effect.control_id == operation["control_id"],
             true <- effect.control_revision == operation["control_revision"],
             true <- effect.operation == operation["operation"],
             true <- effect.scope == operation["scope"],
             true <- effect.ticket_id == operation["ticket_id"],
             true <- effect.attempt_id == operation["attempt_id"],
             true <- effect.execution_id == operation["execution_id"],
             true <- effect.request_id == operation["request"]["request_id"],
             true <- effect.role == operation["request"]["role"],
             true <-
               effect.assignment_id ==
                 assignment_id(
                   operation["ticket_id"],
                   operation["attempt_id"],
                   operation["request"]["role"]
                 ),
             true <-
               effect.phase_generation ==
                 Map.get(operation["request"], "phase_generation", 0),
             true <-
               effect.operation_ordinal ==
                 Map.get(operation["request"], "operation_ordinal", 0),
             true <-
               effect.predecessor_effect_id == operation["request"]["predecessor_effect_id"],
             true <- effect.profile == Map.get(operation["request"], "profile", "unspecified"),
             true <- effect.deadline == operation["request"]["deadline"],
             true <- effect.reservation_ids == operation["reservation_ids"],
             {:ok, lease_specs} <- normalize_lease_specs(operation["leases"]),
             true <- effect.lease_specs == lease_specs do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_effects", id}}}
        end
      end)
    end
  end

  defp validate_claim_command_provenance(conn) do
    with {:ok, command_rows} <-
           Database.query(
             conn,
             "SELECT operation, canonical_request, result FROM root_commands WHERE disposition = 'accepted' AND operation IN ('claim_effect', 'reclaim_claim') ORDER BY seq"
           ),
         {:ok, origins} <- claim_epoch_origins(command_rows),
         {:ok, claim_rows} <- Database.query(conn, "SELECT claim_id FROM root_claims") do
      Enum.reduce_while(claim_rows, :ok, fn [id], :ok ->
        with {:ok, claim} <- load_claim(conn, id),
             %{effect_id: effect_id, writer_epoch: writer_epoch} <- Map.get(origins, id),
             true <- claim.effect_id == effect_id and claim.writer_epoch == writer_epoch do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_claims", :command_provenance}}}
        end
      end)
    end
  end

  defp claim_epoch_origins(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn [type, request_bytes, result_bytes], {:ok, acc} ->
      with {:ok, %{"request" => %{"operation" => operation}}} <- decode(request_bytes),
           ^type <- operation["type"],
           {:ok, result} <- decode(result_bytes),
           claim when is_map(claim) <- get_in(result, ["facts", "claim"]) do
        update_claim_epoch_origin(acc, operation, claim)
      else
        _ -> {:halt, {:error, :invalid_claim_command_provenance}}
      end
    end)
  end

  defp update_claim_epoch_origin(acc, %{"type" => "claim_effect"} = operation, claim) do
    id = operation["claim_id"]

    with false <- Map.has_key?(acc, id),
         true <- claim["claim_id"] == id and claim["effect_id"] == operation["effect_id"],
         true <- claim["writer_epoch"] == operation["writer_epoch"],
         true <- claim["status"] == "claimed" and claim["revision"] == 0 do
      {:cont,
       {:ok,
        Map.put(acc, id, %{
          effect_id: operation["effect_id"],
          writer_epoch: operation["writer_epoch"]
        })}}
    else
      _ -> {:halt, {:error, :invalid_claim_command_provenance}}
    end
  end

  defp update_claim_epoch_origin(acc, %{"type" => "reclaim_claim"} = operation, claim) do
    id = operation["claim_id"]

    with %{writer_epoch: prior} = origin <- Map.get(acc, id),
         true <- prior == operation["prior_writer_epoch"],
         true <- operation["proof"] == "issuer_quiescent",
         true <- operation["new_writer_epoch"] != prior,
         true <- claim["claim_id"] == id,
         true <- claim["effect_id"] == origin.effect_id,
         true <- claim["writer_epoch"] == operation["new_writer_epoch"],
         true <- claim["status"] == "claimed" do
      {:cont, {:ok, Map.put(acc, id, %{origin | writer_epoch: operation["new_writer_epoch"]})}}
    else
      _ -> {:halt, {:error, :invalid_claim_command_provenance}}
    end
  end

  defp validate_reservation_command_provenance(conn) do
    with {:ok, command_rows} <-
           Database.query(
             conn,
             "SELECT canonical_request FROM root_commands WHERE operation = 'reserve' AND disposition = 'accepted' ORDER BY seq"
           ),
         {:ok, origins} <- reservation_origins(command_rows),
         {:ok, reservation_rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations"
           ) do
      Enum.reduce_while(reservation_rows, :ok, fn row, :ok ->
        reservation = reservation_from_row(row)

        with operation when is_map(operation) <- Map.get(origins, reservation.reservation_id),
             true <- reservation.ledger_id == operation["ledger_id"],
             true <- reservation.generation == operation["generation"],
             true <- reservation.owner_kind == operation["owner_kind"],
             true <- reservation.owner_id == operation["owner_id"],
             true <- reservation.units == operation["units"],
             :ok <- validate_reservation_transition_status(conn, reservation) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_reservations", :transition}}}
        end
      end)
    end
  end

  defp reservation_origins(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn [bytes], {:ok, acc} ->
      with {:ok, %{"request" => %{"operation" => %{"type" => "reserve"} = operation}}} <-
             decode(bytes),
           id when is_binary(id) <- operation["reservation_id"],
           false <- Map.has_key?(acc, id) do
        {:cont, {:ok, Map.put(acc, id, operation)}}
      else
        _ -> {:halt, {:error, :invalid_reservation_command_provenance}}
      end
    end)
  end

  defp validate_reservation_transition_status(conn, reservation) do
    if reservation.status in ["released", "retired"] and
         reservation_explicitly_released?(conn, reservation.reservation_id) do
      :ok
    else
      validate_reservation_owner_status(conn, reservation)
    end
  end

  defp validate_reservation_owner_status(conn, reservation) do
    case load_effect(conn, reservation.owner_id) do
      {:error, :not_found} ->
        if reservation.status == "proposed" and is_nil(reservation.claim_id),
          do: :ok,
          else: {:error, :invalid_reservation_transition}

      {:ok, effect} ->
        with {:ok, claims} <-
               Database.query(conn, "SELECT claim_id FROM root_claims WHERE effect_id = ?", [
                 effect.effect_id
               ]),
             claim_id <- if(claims == [], do: nil, else: claims |> hd() |> hd()),
             true <- reservation.claim_id == claim_id,
             true <- reservation.status in reservation_statuses(conn, effect, claim_id) do
          :ok
        else
          _ -> {:error, :invalid_reservation_transition}
        end

      _ ->
        {:error, :invalid_reservation_transition}
    end
  end

  defp reservation_explicitly_released?(conn, reservation_id) do
    case Database.query(
           conn,
           "SELECT canonical_request FROM root_commands WHERE operation = 'release_reservation' AND disposition = 'accepted' ORDER BY seq",
           []
         ) do
      {:ok, rows} ->
        Enum.any?(rows, fn [bytes] ->
          case decode(bytes) do
            {:ok, %{"request" => %{"operation" => operation}}} ->
              operation["reservation_id"] == reservation_id and operation["proof"] == "unissued"

            _ ->
              false
          end
        end)

      _ ->
        false
    end
  end

  defp reservation_statuses(_conn, %{status: "pending"}, nil), do: ["reserved"]

  defp reservation_statuses(_conn, %{status: "claimed"}, claim_id) when is_binary(claim_id),
    do: ["reserved"]

  defp reservation_statuses(_conn, %{status: status}, claim_id)
       when status in ["issued", "unknown"] and is_binary(claim_id),
       do: ["issued_unknown"]

  defp reservation_statuses(conn, %{status: "reconciliation_required"}, claim_id)
       when is_binary(claim_id) do
    case receipts_for_claim(conn, claim_id) do
      {:ok, receipts} ->
        cond do
          Enum.any?(receipts, &(&1.outcome in ["succeeded", "failed"])) -> ["consumed"]
          Enum.any?(receipts, &(&1.outcome == "non_started")) -> ["released", "retired"]
          true -> ["issued_unknown"]
        end

      _ ->
        []
    end
  end

  defp reservation_statuses(_conn, %{status: status}, claim_id)
       when status in ["succeeded", "failed"] and is_binary(claim_id),
       do: ["consumed"]

  defp reservation_statuses(_conn, %{status: "non_started"}, claim_id)
       when is_binary(claim_id),
       do: ["released", "retired"]

  defp reservation_statuses(_conn, %{status: "cancelled"}, _claim_id),
    do: ["released", "retired"]

  defp reservation_statuses(_conn, _effect, _claim_id), do: []

  defp validate_effect_authority_relations(conn) do
    with {:ok, rows} <-
           Database.query(conn, "SELECT effect_id FROM root_effects ORDER BY effect_id") do
      Enum.reduce_while(rows, :ok, fn [id], :ok ->
        with {:ok, effect} <- load_effect(conn, id),
             true <-
               effect.assignment_id ==
                 assignment_id(effect.ticket_id, effect.attempt_id, effect.role),
             true <- effect.scope == "ticket:" <> effect.ticket_id,
             {:ok, dimension} <- required_dimension(effect.operation, effect.role),
             {:ok, reservations} <- reservations_for_effect(conn, id),
             true <-
               Enum.map(reservations, & &1.reservation_id) == Enum.sort(effect.reservation_ids),
             true <- Enum.all?(reservations, &(&1.dimension == dimension and &1.owner_id == id)),
             :ok <- validate_effect_claim_owners(conn, effect, reservations) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_effects", id}}}
        end
      end)
    end
  end

  defp validate_effect_claim_owners(conn, effect, reservations) do
    with {:ok, claims} <-
           Database.query(conn, "SELECT claim_id FROM root_claims WHERE effect_id = ?", [
             effect.effect_id
           ]),
         true <- length(claims) <= 1,
         claim_id <-
           (case claims do
              [[id]] -> id
              [] -> nil
            end),
         true <- Enum.all?(reservations, &(&1.claim_id == claim_id or is_nil(&1.claim_id))),
         {:ok, leases} <-
           Database.query(
             conn,
             "SELECT lease_id, resource_id FROM root_leases WHERE claim_id = ? ORDER BY lease_id",
             [claim_id || ""]
           ),
         expected_leases <-
           effect.lease_specs
           |> Enum.map(&[&1["lease_id"], &1["resource_id"]])
           |> Enum.sort(),
         true <- leases == [] or leases == expected_leases do
      :ok
    else
      _ -> {:error, :invalid_effect_owner_relation}
    end
  end

  defp validate_receipt_provenance(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT r.receipt_id, r.claim_id, r.request_id, r.outcome, r.receipt_digest, r.state, e.state FROM root_receipts r JOIN root_claims c ON c.claim_id = r.claim_id JOIN root_effects e ON e.effect_id = c.effect_id ORDER BY r.receipt_id"
           ) do
      Enum.reduce_while(rows, :ok, fn [id, claim, request, outcome, digest, bytes, effect_bytes],
                                      :ok ->
        with {:ok, effect_state} <- decode(effect_bytes),
             true <- request == effect_state["request_id"],
             {:ok, state} <- decode(bytes),
             true <- state["receipt_id"] == id and state["claim_id"] == claim,
             true <- state["request_id"] == request and state["outcome"] == outcome,
             true <- state["receipt_digest"] == digest,
             :ok <- settlement_proof(outcome, state["proof"]),
             {:ok, ^digest} <-
               Encoding.semantic_digest("foundry-root-receipt-v1", %{
                 "claim_id" => claim,
                 "request_id" => request,
                 "outcome" => outcome,
                 "proof" => state["proof"],
                 "payload" => state["payload"]
               }) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_receipts", id}}}
        end
      end)
    end
  end

  defp validate_request_ownership(conn) do
    with {:ok, effect_rows} <- Database.query(conn, "SELECT effect_id FROM root_effects"),
         {:ok, request_ids} <-
           Enum.reduce_while(effect_rows, {:ok, []}, fn [id], {:ok, acc} ->
             case load_effect(conn, id) do
               {:ok, effect} -> {:cont, {:ok, [effect.request_id | acc]}}
               _ -> {:halt, {:error, :invalid_effect_request_owner}}
             end
           end),
         {:ok, conflicts} <-
           Database.query(
             conn,
             "SELECT request_id FROM root_receipts GROUP BY request_id HAVING count(DISTINCT claim_id) != 1"
           ) do
      if length(request_ids) == MapSet.size(MapSet.new(request_ids)) and conflicts == [],
        do: :ok,
        else: {:error, {:protected_corrupt, "root_receipts", :request_ownership}}
    end
  end

  defp validate_state_bindings(conn) do
    with :ok <- validate_reservation_states(conn),
         :ok <- validate_effect_states(conn),
         :ok <- validate_claim_states(conn),
         :ok <- validate_receipt_states(conn),
         :ok <- validate_lease_states(conn) do
      :ok
    end
  end

  defp validate_reservation_states(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id, state FROM root_reservations"
           ) do
      validate_encoded_rows(rows, "root_reservations", fn row ->
        {columns, [bytes]} = Enum.split(row, 10)
        {public_reservation(reservation_from_row(columns)), bytes}
      end)
    end
  end

  defp validate_effect_states(conn) do
    with {:ok, rows} <- Database.query(conn, "SELECT effect_id, state FROM root_effects") do
      validate_encoded_rows(rows, "root_effects", fn [id, bytes] ->
        {:ok, effect} = load_effect(conn, id)
        {public_effect(effect), bytes}
      end)
    end
  end

  defp validate_claim_states(conn) do
    with {:ok, rows} <- Database.query(conn, "SELECT claim_id, state FROM root_claims") do
      validate_encoded_rows(rows, "root_claims", fn [id, bytes] ->
        {:ok, claim} = load_claim(conn, id)
        {public_claim(claim), bytes}
      end)
    end
  end

  defp validate_receipt_states(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT receipt_id, claim_id, request_id, outcome, receipt_digest, state FROM root_receipts"
           ) do
      validate_encoded_rows(rows, "root_receipts", fn [id, claim, request, outcome, digest, bytes] ->
        {:ok, state} = decode(bytes)

        expected =
          state
          |> Map.put("receipt_id", id)
          |> Map.put("claim_id", claim)
          |> Map.put("request_id", request)
          |> Map.put("outcome", outcome)
          |> Map.put("receipt_digest", digest)

        {expected, bytes}
      end)
    end
  end

  defp validate_lease_states(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT lease_id, claim_id, resource_id, status, revision, state FROM root_leases"
           ) do
      validate_encoded_rows(rows, "root_leases", fn [id, claim, resource, status, revision, bytes] ->
        {%{
           "schema_version" => 1,
           "lease_id" => id,
           "claim_id" => claim,
           "resource_id" => resource,
           "status" => status,
           "revision" => revision
         }, bytes}
      end)
    end
  end

  defp validate_encoded_rows(rows, table, mapper) do
    Enum.reduce_while(rows, :ok, fn row, :ok ->
      try do
        {expected, bytes} = mapper.(row)

        case encode(expected) do
          {:ok, ^bytes} -> {:cont, :ok}
          _ -> {:halt, {:error, {:protected_corrupt, table, :column_state_mismatch}}}
        end
      rescue
        _ -> {:halt, {:error, {:protected_corrupt, table, :invalid_state_binding}}}
      end
    end)
  end
end
