defmodule Foundry.DurableStore.Protected.Reads do
  @moduledoc false

  alias Foundry.DurableStore.{Database, Encoding}

  import Foundry.DurableStore.Protected.Rows

  @effect_observation_sections ~w(claims receipts reservations leases)
  @effect_observation_max_items 50
  @effect_observation_max_offset 1_000_000
  @effect_observation_min_bytes 1_024
  @effect_observation_max_bytes 262_144
  @effect_observation_max_scalar_bytes 256

  @doc false
  def authority_mode(conn) do
    with {:ok, [[root_count]]} <- Database.query(conn, "SELECT count(*) FROM root_commands"),
         {:ok, [[legacy_count]]} <-
           Database.query(
             conn,
             "SELECT (SELECT count(*) FROM claims) + (SELECT count(*) FROM reservations) + (SELECT count(*) FROM ledger_generations) + (SELECT count(*) FROM receipts) + (SELECT count(*) FROM leases)"
           ) do
      case {root_count, legacy_count} do
        {root, 0} when root > 0 -> {:ok, :root}
        {0, legacy} when legacy > 0 -> {:ok, :legacy}
        {0, 0} -> {:ok, :empty_or_legacy}
        _ -> {:error, :conflicting_authority_modes}
      end
    end
  end

  @doc false
  def query(conn, query) do
    with {:ok, query} <- string_map(query),
         1 <- query["schema_version"],
         type when is_binary(type) <- query["type"] do
      case type do
        "inbox" ->
          inbox_fact(conn, query["execution_id"])

        "policy" ->
          simple_fact(conn, "root_policies", "policy_id", query["policy_id"])

        "control" ->
          simple_fact(conn, "root_controls", "control_id", query["control_id"])

        "ledger" ->
          ledger_fact(conn, query["ledger_id"], query["generation"])

        "effect" ->
          effect_fact(conn, query["effect_id"])

        "effect_observation_page" ->
          effect_observation_page(conn, query)

        "claim" ->
          claim_fact(conn, query["claim_id"])

        "reservation" ->
          reservation_fact(conn, query["reservation_id"])

        "receipt" ->
          receipt_fact(conn, query["receipt_id"])

        "lease" ->
          lease_fact(conn, query["lease_id"])

        "command" ->
          command_fact(conn, query["command_id"])

        "infrastructure_settlement" ->
          protected_row(
            conn,
            "SELECT state FROM root_infrastructure_settlements WHERE effect_id = ?",
            [query["effect_id"]]
          )

        "pointer" ->
          pointer_fact(conn, query["pointer_kind"])

        _ ->
          {:error, :unsupported_protected_query}
      end
    else
      _ -> {:error, :invalid_protected_query}
    end
  end

  @doc false
  def snapshot(conn, writer_epoch) do
    with :ok <- identity(writer_epoch),
         {:ok, metadata_rows} <- Database.query(conn, "SELECT key, value FROM metadata"),
         metadata <- Map.new(metadata_rows, fn [key, value] -> {key, value} end),
         {:ok, [[event_seq]]} <- Database.query(conn, "SELECT coalesce(max(seq), 0) FROM events"),
         {:ok, [[root_seq]]} <-
           Database.query(conn, "SELECT coalesce(max(seq), 0) FROM root_commands"),
         {:ok, authority_mode} <- authority_mode(conn),
         {:ok, revision_frontiers} <- revision_frontiers(conn),
         {:ok, pointers} <- all_pointer_facts(conn) do
      {:ok,
       %{
         "schema_version" => 1,
         "installation_id" => metadata["installation_id"],
         "repository_id" => metadata["repository_id"],
         "writer_epoch" => writer_epoch,
         "sql_schema_version" => metadata["schema_version"],
         "protected_schema_version" => metadata["protected_schema_version"],
         "protocol_version" => metadata["protocol_version"],
         "event_version" => metadata["event_version"],
         "projection_version" => metadata["projection_version"],
         "last_domain_event_sequence" => event_seq,
         "last_protected_command_sequence" => root_seq,
         "authority_mode" => Atom.to_string(authority_mode),
         "fact_revision_frontiers" => revision_frontiers,
         "pointers" => pointers
       }}
    end
  end

  defp simple_fact(conn, table, column, id) do
    with {:ok, %{value: value, revision: revision}} <- load_simple(conn, table, column, id) do
      {:ok, %{"schema_version" => 1, column => id, "revision" => revision, "value" => value}}
    end
  end

  defp effect_observation_page(conn, query) do
    with {:ok, request} <- normalize_effect_observation_request(query) do
      Database.transaction(conn, fn -> effect_observation_snapshot(conn, request) end)
    end
  end

  defp normalize_effect_observation_request(query) do
    with :ok <-
           exact_keys(query, ~w(schema_version type effect_id limit max_bytes cursor)),
         :ok <- bounded_observation_identity(query["effect_id"]),
         limit when is_integer(limit) and limit in 1..@effect_observation_max_items <-
           query["limit"],
         max_bytes
         when is_integer(max_bytes) and max_bytes >= @effect_observation_min_bytes and
                max_bytes <= @effect_observation_max_bytes <- query["max_bytes"],
         {:ok, cursor} <- normalize_effect_observation_cursor(query["cursor"]) do
      {:ok,
       %{
         effect_id: query["effect_id"],
         limit: limit,
         max_bytes: max_bytes,
         cursor: cursor
       }}
    else
      _ -> {:error, :invalid_protected_query}
    end
  end

  defp normalize_effect_observation_cursor(nil), do: {:ok, nil}

  defp normalize_effect_observation_cursor(cursor) do
    with {:ok, cursor} <- string_map(cursor),
         :ok <-
           exact_keys(
             cursor,
             ~w(schema_version query_type scope_digest source_digest protected_sequence effect_revision section offset)
           ),
         1 <- cursor["schema_version"],
         "effect_observation_page" <- cursor["query_type"],
         true <- digest_string?(cursor["scope_digest"]),
         true <- digest_string?(cursor["source_digest"]),
         sequence when is_integer(sequence) and sequence >= 0 <- cursor["protected_sequence"],
         revision when is_integer(revision) and revision >= 0 <- cursor["effect_revision"],
         section when section in @effect_observation_sections <- cursor["section"],
         offset
         when is_integer(offset) and offset >= 0 and
                offset <= @effect_observation_max_offset <- cursor["offset"] do
      {:ok, cursor}
    else
      _ -> {:error, :invalid_protected_query}
    end
  end

  defp effect_observation_snapshot(conn, request) do
    with {:ok, source} <- effect_observation_source(conn),
         {:ok, effect} <- bounded_effect_header(conn, request.effect_id),
         {:ok, scope_digest} <-
           Encoding.semantic_digest("foundry-effect-observation-scope-v1", %{
             "effect_id" => request.effect_id
           }),
         {:ok, source_digest} <-
           Encoding.semantic_digest("foundry-effect-observation-source-v1", %{
             "installation_id" => source["installation_id"],
             "repository_id" => source["repository_id"]
           }),
         :ok <-
           validate_effect_observation_cursor(
             request.cursor,
             scope_digest,
             source_digest,
             source["last_protected_command_sequence"],
             effect["revision"]
           ),
         {:ok, control} <- bounded_effect_control(conn, effect),
         {:ok, execution} <- bounded_effect_execution(conn, effect),
         {:ok, settlement} <- bounded_infrastructure_settlement(conn, effect),
         context <- %{
           source: Map.put(source, "effect_revision", effect["revision"]),
           effect: effect,
           control: control,
           execution: execution,
           settlement: settlement,
           scope_digest: scope_digest,
           source_digest: source_digest,
           protected_sequence: source["last_protected_command_sequence"],
           effect_revision: effect["revision"],
           limit: request.limit,
           max_bytes: request.max_bytes
         },
         {:ok, state} <- initial_effect_observation_state(context, request.cursor),
         {:ok, completed} <- read_effect_observation_sections(conn, context, state),
         response <- effect_observation_response(context, completed),
         true <- :erlang.external_size(response) <= context.max_bytes do
      {:ok, response}
    else
      false -> {:error, :protected_observation_oversized}
      error -> error
    end
  end

  # These summaries deliberately select only bounded scalar prefixes. In particular,
  # neither the control state nor inbox item blobs cross the SQLite boundary.
  defp bounded_effect_control(conn, effect) do
    columns = [
      {"control_id", :text},
      {"revision", :integer},
      {"json_extract(CAST(state AS TEXT), '$.value.status')", "status", :text}
    ]

    sql = "SELECT " <> bounded_select_list(columns) <> " FROM root_controls WHERE control_id = ?"

    with {:ok, rows} <- Database.query(conn, sql, [effect["control_id"]]),
         [row] <- rows,
         {:ok, control} <- decode_bounded_row(row, columns),
         true <- control["control_id"] == effect["control_id"],
         true <- nonnegative_integer?(control["revision"]),
         true <- control["status"] in ~w(active cancel_requested) do
      {:ok, Map.put(control, "schema_version", 1)}
    else
      {:error, _reason} = error -> error
      _ -> protected_observation_corrupt(effect["effect_id"])
    end
  end

  defp bounded_effect_execution(conn, effect) do
    columns = [
      {"i.execution_id", "execution_id", :text},
      {"i.revision", "revision", :integer},
      {"i.last_sequence", "last_sequence", :integer},
      {"coalesce(i.sealed_sequence, -1)", "sealed_sequence", :integer},
      {"coalesce((SELECT min(x.sequence) FROM authenticated_inbox_items x WHERE x.execution_id = i.execution_id AND x.disposition = 'accepted' AND x.item_kind = 'result'), -1)",
       "result_sequence", :integer},
      {"coalesce((SELECT min(x.sequence) FROM authenticated_inbox_items x WHERE x.execution_id = i.execution_id AND x.disposition = 'accepted' AND x.item_kind = 'exit'), -1)",
       "exit_sequence", :integer}
    ]

    sql =
      "SELECT " <>
        bounded_select_list(columns) <>
        " FROM authenticated_inboxes i WHERE i.execution_id = ?"

    with {:ok, rows} <- Database.query(conn, sql, [effect["execution_id"]]) do
      case rows do
        [] ->
          {:ok,
           %{
             "schema_version" => 1,
             "execution_id" => effect["execution_id"],
             "status" => "absent"
           }}

        [row] ->
          with {:ok, inbox} <- decode_bounded_row(row, columns),
               true <- inbox["execution_id"] == effect["execution_id"],
               true <- nonnegative_integer?(inbox["revision"]),
               true <- nonnegative_integer?(inbox["last_sequence"]),
               {:ok, summary} <- bounded_execution_summary(inbox) do
            {:ok, Map.merge(%{"schema_version" => 1}, summary)}
          else
            {:error, _reason} = error -> error
            _ -> protected_observation_corrupt(effect["effect_id"])
          end

        _ ->
          protected_observation_corrupt(effect["effect_id"])
      end
    end
  end

  defp bounded_execution_summary(%{"sealed_sequence" => -1} = inbox) do
    {:ok,
     inbox
     |> Map.take(~w(execution_id revision last_sequence))
     |> Map.put("sealed_sequence", nil)
     |> Map.put("status", "open")}
  end

  defp bounded_execution_summary(inbox) do
    sealed = inbox["sealed_sequence"]
    result = inbox["result_sequence"]
    exit = inbox["exit_sequence"]

    with true <- nonnegative_integer?(sealed) and sealed <= inbox["last_sequence"],
         true <- result == -1 or (is_integer(result) and result in 1..sealed),
         true <- exit == -1 or (is_integer(exit) and exit in 1..sealed) do
      {status, sequence} =
        cond do
          result != -1 -> {"result", result}
          exit != -1 -> {"exit", exit}
          true -> {"sealed_without_result_or_exit", nil}
        end

      summary =
        inbox
        |> Map.take(~w(execution_id revision last_sequence sealed_sequence))
        |> Map.put("status", status)

      {:ok, if(is_nil(sequence), do: summary, else: Map.put(summary, "sequence", sequence))}
    else
      _ -> protected_observation_corrupt(inbox["execution_id"])
    end
  end

  defp effect_observation_source(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT key, CAST(substr(CAST(value AS BLOB), 1, ? + 1) AS TEXT), length(CAST(value AS BLOB)) FROM metadata WHERE key IN ('installation_id', 'repository_id') ORDER BY key",
             [@effect_observation_max_scalar_bytes]
           ),
         {:ok, metadata} <- bounded_metadata(rows),
         {:ok, [[sequence]]} <-
           Database.query(conn, "SELECT coalesce(max(seq), 0) FROM root_commands"),
         true <- is_integer(sequence) and sequence >= 0 do
      {:ok,
       %{
         "installation_id" => metadata["installation_id"],
         "repository_id" => metadata["repository_id"],
         "last_protected_command_sequence" => sequence
       }}
    else
      {:error, _reason} = error -> error
      _ -> protected_observation_corrupt(:source)
    end
  end

  defp bounded_metadata(rows) when length(rows) == 2 do
    Enum.reduce_while(rows, {:ok, %{}}, fn
      [key, value, bytes], {:ok, acc} when key in ["installation_id", "repository_id"] ->
        case bounded_text_value(value, bytes, false) do
          {:ok, decoded} -> {:cont, {:ok, Map.put(acc, key, decoded)}}
          {:error, _reason} = error -> {:halt, error}
        end

      _row, _acc ->
        {:halt, protected_observation_corrupt(:source)}
    end)
    |> case do
      {:ok, %{"installation_id" => _, "repository_id" => _} = metadata} -> {:ok, metadata}
      {:ok, _metadata} -> protected_observation_corrupt(:source)
      error -> error
    end
  end

  defp bounded_metadata(_rows), do: protected_observation_corrupt(:source)

  defp bounded_effect_header(conn, effect_id) do
    columns = [
      {"effect_id", :text},
      {"ticket_id", :text},
      {"attempt_id", :text},
      {"execution_id", :text},
      {"control_id", :text},
      {"policy_id", :text},
      {"operation", :text},
      {"scope", :text},
      {"status", :text},
      {"revision", :integer},
      {"policy_revision", :integer},
      {"control_revision", :integer}
    ]

    sql =
      "SELECT " <> bounded_select_list(columns) <> " FROM root_effects WHERE effect_id = ?"

    with {:ok, rows} <- Database.query(conn, sql, [effect_id]) do
      case rows do
        [] ->
          {:error, :not_found}

        [row] ->
          with {:ok, effect} <- decode_bounded_row(row, columns),
               ^effect_id <- effect["effect_id"],
               true <-
                 effect["status"] in ~w(pending claimed issued unknown succeeded failed non_started cancelled reconciliation_required),
               true <- nonnegative_integer?(effect["revision"]),
               true <- nonnegative_integer?(effect["policy_revision"]),
               true <- nonnegative_integer?(effect["control_revision"]) do
            {:ok, Map.put(effect, "schema_version", 1)}
          else
            {:error, _reason} = error -> error
            _ -> protected_observation_corrupt(effect_id)
          end

        _ ->
          protected_observation_corrupt(effect_id)
      end
    end
  end

  defp bounded_infrastructure_settlement(conn, effect) do
    effect_id = effect["effect_id"]

    columns = [
      {"s.effect_id", "effect_id", :text},
      {"s.claim_id", "claim_id", :text},
      {"s.receipt_id", "receipt_id", :text},
      {"s.role", "role", :text},
      {"s.work_owner", "work_owner", :text},
      {"s.infrastructure_generation", "infrastructure_generation", :integer},
      {"s.predecessor_effect_id", "predecessor_effect_id", :nullable_text},
      {"s.failure_class", "failure_class", :text},
      {"s.ordinal", "ordinal", :integer},
      {"c.effect_id", "claim_effect_id", :text},
      {"c.status", "claim_status", :text},
      {"r.claim_id", "receipt_claim_id", :text},
      {"r.outcome", "receipt_outcome", :text},
      {"json_extract(CAST(e.state AS TEXT), '$.role')", "effect_role", :text},
      {"json_extract(CAST(e.state AS TEXT), '$.assignment_id')", "effect_work_owner", :text},
      {"json_extract(CAST(e.state AS TEXT), '$.phase_generation')", "effect_generation",
       :integer},
      {"json_extract(CAST(e.state AS TEXT), '$.predecessor_effect_id')", "effect_predecessor",
       :nullable_text},
      {"json_extract(CAST(r.state AS TEXT), '$.payload.failure_class')", "receipt_failure_class",
       :text}
    ]

    sql =
      "SELECT " <>
        bounded_select_list(columns) <>
        " FROM root_infrastructure_settlements s " <>
        "JOIN root_claims c ON c.claim_id = s.claim_id " <>
        "JOIN root_receipts r ON r.receipt_id = s.receipt_id " <>
        "JOIN root_effects e ON e.effect_id = s.effect_id " <>
        "WHERE s.effect_id = ?"

    with {:ok, rows} <- Database.query(conn, sql, [effect_id]),
         {:ok, required} <- required_infrastructure_settlement(conn, effect_id) do
      case {rows, required} do
        {[], nil} ->
          {:ok, nil}

        {[], required} when is_map(required) ->
          protected_observation_corrupt(effect_id)

        {[row], required} when is_map(required) ->
          with {:ok, value} <- decode_bounded_row(row, columns),
               ^effect_id <- value["effect_id"],
               ^effect_id <- value["claim_effect_id"],
               claim_id when is_binary(claim_id) <- value["claim_id"],
               ^claim_id <- value["receipt_claim_id"],
               true <- valid_settlement_current_status?(conn, effect, value),
               "non_started" <- value["receipt_outcome"],
               true <- value["role"] == value["effect_role"],
               true <- value["work_owner"] == value["effect_work_owner"],
               true <- value["infrastructure_generation"] == value["effect_generation"],
               true <- value["predecessor_effect_id"] == value["effect_predecessor"],
               true <- value["failure_class"] == value["receipt_failure_class"],
               true <- settlement_matches_required?(value, required),
               :ok <- validate_bounded_settlement_lineage(conn, value) do
            {:ok,
             value
             |> Map.drop(
               ~w(claim_effect_id claim_status receipt_claim_id receipt_outcome effect_role effect_work_owner effect_generation effect_predecessor receipt_failure_class)
             )
             |> Map.put("schema_version", 1)}
          else
            {:error, _reason} = error -> error
            _ -> protected_observation_corrupt(effect_id)
          end

        _ ->
          protected_observation_corrupt(effect_id)
      end
    end
  end

  defp required_infrastructure_settlement(conn, effect_id) do
    columns = [
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.effect_id')",
       "effect_id", :text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.claim_id')",
       "claim_id", :text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.receipt_id')",
       "receipt_id", :text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.role')",
       "role", :text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.work_owner')",
       "work_owner", :text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.infrastructure_generation')",
       "infrastructure_generation", :integer},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.predecessor_effect_id')",
       "predecessor_effect_id", :nullable_text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.failure_class')",
       "failure_class", :text},
      {"json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.infrastructure_settlement.ordinal')",
       "ordinal", :integer}
    ]

    sql =
      "SELECT " <>
        bounded_select_list(columns) <>
        " FROM durable_operations d " <>
        "JOIN atomic_bundles b ON b.command_id = d.owner_id " <>
        "WHERE d.owner_kind = 'bundle_v2' AND d.operation_kind = 'protected' " <>
        "AND d.operation_type = 'settle_claim' AND b.disposition = 'accepted' " <>
        "AND json_extract(CAST(d.request AS TEXT), '$.operation.outcome') = 'non_started' " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.execution_status') = 'committed' " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.effect.effect_id') = ?"

    case Database.query(conn, sql, [effect_id]) do
      {:ok, []} -> {:ok, nil}
      {:ok, [row]} -> decode_bounded_row(row, columns)
      {:error, _reason} = error -> error
      _ -> protected_observation_corrupt(effect_id)
    end
  end

  defp settlement_matches_required?(value, required) do
    Enum.all?(
      ~w(effect_id claim_id receipt_id role work_owner infrastructure_generation predecessor_effect_id failure_class ordinal),
      &(value[&1] == required[&1])
    )
  end

  defp validate_bounded_settlement_lineage(_conn, %{
         "predecessor_effect_id" => nil,
         "ordinal" => 1
       }),
       do: :ok

  defp validate_bounded_settlement_lineage(conn, value) do
    columns = [
      {"role", :text},
      {"work_owner", :text},
      {"infrastructure_generation", :integer},
      {"ordinal", :integer}
    ]

    sql =
      "SELECT " <>
        bounded_select_list(columns) <>
        " FROM root_infrastructure_settlements WHERE effect_id = ?"

    with predecessor when is_binary(predecessor) <- value["predecessor_effect_id"],
         {:ok, [row]} <- Database.query(conn, sql, [predecessor]),
         {:ok, prior} <- decode_bounded_row(row, columns),
         true <- prior["role"] == value["role"],
         true <- prior["work_owner"] == value["work_owner"],
         true <- prior["infrastructure_generation"] == value["infrastructure_generation"],
         true <- prior["ordinal"] + 1 == value["ordinal"] do
      :ok
    else
      _ -> protected_observation_corrupt(value["effect_id"])
    end
  end

  defp valid_settlement_current_status?(_conn, %{"status" => "non_started"}, %{
         "claim_status" => "non_started"
       }),
       do: true

  defp valid_settlement_current_status?(
         conn,
         %{"effect_id" => effect_id, "status" => "reconciliation_required"},
         %{
           "claim_id" => claim_id,
           "claim_status" => "reconciliation_required"
         }
       ) do
    sql =
      "SELECT count(*) FROM durable_operations d JOIN atomic_bundles b ON b.command_id = d.owner_id " <>
        "WHERE d.owner_kind = 'bundle_v2' AND d.operation_kind = 'protected' " <>
        "AND d.operation_type = 'settle_claim' AND b.disposition = 'quarantined' " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.execution_status') = 'committed' " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.effect.effect_id') = ? " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.effect.status') = 'reconciliation_required' " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.claim.claim_id') = ? " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.claim.status') = 'reconciliation_required' " <>
        "AND json_extract(CAST(d.result AS TEXT), '$.operation_result.facts.attempted_receipt.outcome') <> 'non_started'"

    match?({:ok, [[count]]} when count > 0, Database.query(conn, sql, [effect_id, claim_id]))
  end

  defp valid_settlement_current_status?(_conn, _effect, _value), do: false

  defp validate_effect_observation_cursor(
         nil,
         _scope_digest,
         _source_digest,
         _sequence,
         _revision
       ),
       do: :ok

  defp validate_effect_observation_cursor(cursor, scope_digest, source_digest, sequence, revision) do
    cond do
      cursor["scope_digest"] != scope_digest -> {:error, :invalid_protected_query}
      cursor["source_digest"] != source_digest -> {:error, :stale_protected_cursor}
      cursor["protected_sequence"] != sequence -> {:error, :stale_protected_cursor}
      cursor["effect_revision"] != revision -> {:error, :stale_protected_cursor}
      true -> :ok
    end
  end

  defp initial_effect_observation_state(context, cursor) do
    {section, offset} =
      case cursor do
        nil -> {hd(@effect_observation_sections), 0}
        cursor -> {cursor["section"], cursor["offset"]}
      end

    state = %{
      section: section,
      offset: offset,
      relations: [],
      item_count: 0,
      truncated_reason: nil,
      receipts_complete: section in ~w(reservations leases)
    }

    if effect_observation_size(context, state, true) <= context.max_bytes,
      do: {:ok, state},
      else: {:error, :protected_observation_oversized}
  end

  defp read_effect_observation_sections(_conn, _context, %{truncated_reason: reason} = state)
       when not is_nil(reason),
       do: {:ok, state}

  defp read_effect_observation_sections(conn, context, state) do
    section_index = Enum.find_index(@effect_observation_sections, &(&1 == state.section))

    if is_nil(section_index) do
      {:error, :invalid_protected_query}
    else
      with {:ok, read} <- read_effect_observation_section(conn, context, state) do
        cond do
          not is_nil(read.truncated_reason) ->
            {:ok, read}

          section_index == length(@effect_observation_sections) - 1 ->
            {:ok, %{read | section: nil, offset: 0}}

          true ->
            next_section = Enum.at(@effect_observation_sections, section_index + 1)

            read_effect_observation_sections(conn, context, %{
              read
              | section: next_section,
                offset: 0,
                receipts_complete: read.receipts_complete or state.section == "receipts"
            })
        end
      end
    end
  end

  defp read_effect_observation_section(conn, context, state) do
    remaining = context.limit - state.item_count
    {sql, parameters, columns, kind} = observation_section_query(state.section, context.effect)
    params = parameters ++ [remaining + 1, state.offset]

    Database.fold(conn, sql, params, state, fn row, acc ->
      cond do
        acc.item_count >= context.limit ->
          {:halt, {:ok, %{acc | truncated_reason: "item_limit"}}}

        true ->
          case decode_bounded_row(row, columns) do
            {:ok, decoded} ->
              relation = decoded |> Map.put("schema_version", 1) |> Map.put("kind", kind)

              if valid_effect_observation_relation?(relation, context.effect["effect_id"]) do
                candidate = %{
                  acc
                  | relations: acc.relations ++ [relation],
                    item_count: acc.item_count + 1,
                    offset: acc.offset + 1
                }

                if effect_observation_size(context, candidate, true) <= context.max_bytes do
                  {:cont, candidate}
                else
                  {:halt,
                   {:ok,
                    %{
                      acc
                      | truncated_reason:
                          if(acc.item_count == 0, do: "oversized_row", else: "byte_limit")
                    }}}
                end
              else
                {:halt, protected_observation_corrupt(context.effect["effect_id"])}
              end

            {:error, _reason} = error ->
              {:halt, error}
          end
      end
    end)
    |> case do
      {:ok, %{truncated_reason: "oversized_row", item_count: 0}} ->
        {:error, :protected_observation_oversized}

      other ->
        other
    end
  end

  defp observation_section_query("claims", effect) do
    columns = [
      {"claim_id", :text},
      {"effect_id", :text},
      {"writer_epoch", :text},
      {"status", :text},
      {"revision", :integer}
    ]

    {"SELECT " <>
       bounded_select_list(columns) <>
       " FROM root_claims WHERE effect_id = ? ORDER BY claim_id LIMIT ? OFFSET ?",
     [effect["effect_id"]], columns, "claim"}
  end

  defp observation_section_query("receipts", effect) do
    columns = [
      {"r.receipt_id", "receipt_id", :text},
      {"r.claim_id", "claim_id", :text},
      {"r.request_id", "request_id", :text},
      {"r.outcome", "outcome", :text},
      {"r.receipt_digest", "receipt_digest", :text}
    ]

    {"SELECT " <>
       bounded_select_list(columns) <>
       " FROM root_receipts r JOIN root_claims c ON c.claim_id = r.claim_id " <>
       "WHERE c.effect_id = ? ORDER BY r.claim_id, r.receipt_id LIMIT ? OFFSET ?",
     [effect["effect_id"]], columns, "receipt"}
  end

  defp observation_section_query("reservations", effect) do
    columns = [
      {"reservation_id", :text},
      {"ledger_id", :text},
      {"generation", :integer},
      {"dimension", :text},
      {"owner_kind", :text},
      {"owner_id", :text},
      {"units", :integer},
      {"revision", :integer},
      {"status", :text},
      {"claim_id", :nullable_text}
    ]

    {"SELECT " <>
       bounded_select_list(columns) <>
       " FROM root_reservations WHERE owner_kind = 'effect' AND owner_id = ? " <>
       "ORDER BY reservation_id LIMIT ? OFFSET ?", [effect["effect_id"]], columns, "reservation"}
  end

  defp observation_section_query("leases", effect) do
    columns = [
      {"l.lease_id", "lease_id", :text},
      {"l.claim_id", "claim_id", :text},
      {"l.resource_id", "resource_id", :text},
      {"l.status", "status", :text},
      {"l.revision", "revision", :integer}
    ]

    {"SELECT " <>
       bounded_select_list(columns) <>
       " FROM root_leases l JOIN root_claims c ON c.claim_id = l.claim_id " <>
       "WHERE c.effect_id = ? ORDER BY l.claim_id, l.lease_id LIMIT ? OFFSET ?",
     [effect["effect_id"]], columns, "lease"}
  end

  defp valid_effect_observation_relation?(%{"kind" => "claim"} = relation, effect_id) do
    relation["effect_id"] == effect_id and nonempty_text?(relation["claim_id"]) and
      nonempty_text?(relation["writer_epoch"]) and
      relation["status"] in ~w(claimed issued unknown succeeded failed non_started cancelled reconciliation_required) and
      nonnegative_integer?(relation["revision"])
  end

  defp valid_effect_observation_relation?(%{"kind" => "receipt"} = relation, _effect_id) do
    Enum.all?(
      ~w(receipt_id claim_id request_id receipt_digest),
      &nonempty_text?(relation[&1])
    ) and relation["outcome"] in ~w(succeeded failed non_started unknown)
  end

  defp valid_effect_observation_relation?(%{"kind" => "reservation"} = relation, effect_id) do
    nonempty_text?(relation["reservation_id"]) and nonempty_text?(relation["ledger_id"]) and
      nonnegative_integer?(relation["generation"]) and nonempty_text?(relation["dimension"]) and
      relation["owner_kind"] == "effect" and relation["owner_id"] == effect_id and
      is_integer(relation["units"]) and relation["units"] > 0 and
      nonnegative_integer?(relation["revision"]) and
      relation["status"] in ~w(proposed reserved issued_unknown consumed released retired) and
      (is_nil(relation["claim_id"]) or nonempty_text?(relation["claim_id"]))
  end

  defp valid_effect_observation_relation?(%{"kind" => "lease"} = relation, _effect_id) do
    nonempty_text?(relation["lease_id"]) and nonempty_text?(relation["claim_id"]) and
      nonempty_text?(relation["resource_id"]) and
      relation["status"] in ~w(held released retained) and
      nonnegative_integer?(relation["revision"])
  end

  defp valid_effect_observation_relation?(_relation, _effect_id), do: false

  defp effect_observation_response(context, state) do
    next_cursor =
      if is_nil(state.section) do
        nil
      else
        effect_observation_cursor(context, state.section, state.offset)
      end

    response = %{
      "schema_version" => 1,
      "type" => "effect_observation_page",
      "source" => context.source,
      "effect" => context.effect,
      "control" => context.control,
      "execution" => context.execution,
      "relations" => state.relations,
      "infrastructure_settlement" => context.settlement,
      "settlement" => %{
        "schema_version" => 1,
        "status" => context.effect["status"],
        "receipt_history" => if(state.receipts_complete, do: "complete", else: "unknown")
      },
      "page" => %{
        "item_count" => state.item_count,
        "size_bytes" => 0,
        "truncated" => not is_nil(next_cursor),
        "truncated_reason" => state.truncated_reason,
        "next_cursor" => next_cursor
      }
    }

    put_effect_observation_size(response)
  end

  defp effect_observation_size(context, state, assume_truncated?) do
    section = state.section || List.last(@effect_observation_sections)

    provisional = %{
      state
      | section: if(assume_truncated?, do: section, else: state.section),
        truncated_reason: state.truncated_reason || if(assume_truncated?, do: "byte_limit")
    }

    context
    |> effect_observation_response(provisional)
    |> :erlang.external_size()
  end

  defp put_effect_observation_size(response) do
    sized = put_in(response, ["page", "size_bytes"], :erlang.external_size(response))
    stabilize_effect_observation_size(sized)
  end

  defp stabilize_effect_observation_size(response) do
    size = :erlang.external_size(response)

    if response["page"]["size_bytes"] == size,
      do: response,
      else:
        response |> put_in(["page", "size_bytes"], size) |> stabilize_effect_observation_size()
  end

  defp effect_observation_cursor(context, section, offset) do
    %{
      "schema_version" => 1,
      "query_type" => "effect_observation_page",
      "scope_digest" => context.scope_digest,
      "source_digest" => context.source_digest,
      "protected_sequence" => context.protected_sequence,
      "effect_revision" => context.effect_revision,
      "section" => section,
      "offset" => offset
    }
  end

  defp bounded_select_list(columns) do
    columns
    |> Enum.flat_map(fn
      {column, :text} -> bounded_text_select(column)
      {column, :nullable_text} -> bounded_text_select(column)
      {column, :integer} -> [column]
      {column, _key, :text} -> bounded_text_select(column)
      {column, _key, :nullable_text} -> bounded_text_select(column)
      {column, _key, :integer} -> [column]
    end)
    |> Enum.join(", ")
  end

  defp bounded_text_select(column) do
    [
      "CAST(substr(CAST(#{column} AS BLOB), 1, #{@effect_observation_max_scalar_bytes + 1}) AS TEXT)",
      "length(CAST(#{column} AS BLOB))"
    ]
  end

  defp decode_bounded_row(row, columns), do: decode_bounded_row(row, columns, %{})

  defp decode_bounded_row([], [], acc), do: {:ok, acc}

  defp decode_bounded_row([value, bytes | rest], [column | columns], acc)
       when elem(column, tuple_size(column) - 1) in [:text, :nullable_text] do
    {key, kind} = bounded_column_key_kind(column)

    case bounded_text_value(value, bytes, kind == :nullable_text) do
      {:ok, decoded} -> decode_bounded_row(rest, columns, Map.put(acc, key, decoded))
      {:error, _reason} = error -> error
    end
  end

  defp decode_bounded_row([value | rest], [column | columns], acc) do
    {key, :integer} = bounded_column_key_kind(column)

    if is_integer(value) do
      decode_bounded_row(rest, columns, Map.put(acc, key, value))
    else
      protected_observation_corrupt(key)
    end
  end

  defp decode_bounded_row(_row, _columns, _acc), do: protected_observation_corrupt(:row_shape)

  defp bounded_column_key_kind({column, kind}), do: {List.last(String.split(column, ".")), kind}
  defp bounded_column_key_kind({_column, key, kind}), do: {key, kind}

  defp bounded_text_value(nil, nil, true), do: {:ok, nil}

  defp bounded_text_value(value, bytes, _nullable?)
       when is_binary(value) and is_integer(bytes) and bytes >= 0 do
    cond do
      bytes > @effect_observation_max_scalar_bytes ->
        {:error, :protected_observation_oversized}

      bytes == 0 ->
        protected_observation_corrupt(:empty_scalar)

      byte_size(value) != bytes or not String.valid?(value) ->
        protected_observation_corrupt(:invalid_scalar)

      true ->
        {:ok, value}
    end
  end

  defp bounded_text_value(_value, _bytes, _nullable?),
    do: protected_observation_corrupt(:invalid_scalar)

  defp bounded_observation_identity(value) do
    with :ok <- identity(value),
         true <- byte_size(value) <= @effect_observation_max_scalar_bytes do
      :ok
    else
      _ -> {:error, :invalid_identity}
    end
  end

  defp digest_string?(value),
    do: is_binary(value) and byte_size(value) == 64 and String.match?(value, ~r/\A[0-9a-f]+\z/)

  defp nonempty_text?(value), do: is_binary(value) and value != "" and String.valid?(value)

  defp protected_observation_corrupt(identity),
    do: {:error, {:protected_corrupt, "effect_observation_page", identity}}

  defp effect_fact(conn, id) do
    with {:ok, effect} <- load_effect(conn, id),
         {:ok, claims} <-
           Database.query(
             conn,
             "SELECT claim_id FROM root_claims WHERE effect_id = ? ORDER BY claim_id",
             [id]
           ),
         {:ok, reservations} <- reservations_for_effect(conn, id) do
      claim_facts =
        Enum.map(claims, fn [claim_id] ->
          {:ok, claim} = load_claim(conn, claim_id)
          {:ok, receipts} = receipts_for_claim(conn, claim_id)

          public_claim(claim)
          |> Map.put("receipts", Enum.map(receipts, &public_receipt/1))
        end)

      {:ok,
       public_effect(effect)
       |> Map.put("claims", claim_facts)
       |> Map.put("reservations", Enum.map(reservations, &public_reservation/1))}
    end
  end

  defp claim_fact(conn, id) do
    with {:ok, claim} <- load_claim(conn, id),
         {:ok, receipts} <- receipts_for_claim(conn, id),
         {:ok, reservations} <- reservations_for_claim(conn, id),
         {:ok, leases} <-
           protected_rows(
             conn,
             "SELECT state FROM root_leases WHERE claim_id = ? ORDER BY lease_id",
             [id]
           ) do
      {:ok,
       public_claim(claim)
       |> Map.put("receipts", Enum.map(receipts, &public_receipt/1))
       |> Map.put("reservations", Enum.map(reservations, &public_reservation/1))
       |> Map.put("leases", leases)}
    end
  end

  defp reservation_fact(conn, id) do
    with {:ok, reservation} <- load_reservation(conn, id) do
      {:ok, public_reservation(reservation)}
    end
  end

  defp receipt_fact(conn, id) do
    protected_row(conn, "SELECT state FROM root_receipts WHERE receipt_id = ?", [id])
  end

  defp lease_fact(conn, id) do
    protected_row(conn, "SELECT state FROM root_leases WHERE lease_id = ?", [id])
  end

  defp protected_row(conn, sql, parameters) do
    with {:ok, rows} <- protected_rows(conn, sql, parameters) do
      case rows do
        [row] -> {:ok, row}
        [] -> {:error, :not_found}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  defp protected_rows(conn, sql, parameters) do
    with {:ok, rows} <- Database.query(conn, sql, parameters) do
      Enum.reduce_while(rows, {:ok, []}, fn
        [bytes], {:ok, acc} ->
          case decode(bytes) do
            {:ok, value} -> {:cont, {:ok, [value | acc]}}
            {:error, _reason} = error -> {:halt, error}
          end

        _row, _acc ->
          {:halt, {:error, :corrupt_protected_row}}
      end)
      |> then(fn
        {:ok, values} -> {:ok, Enum.reverse(values)}
        error -> error
      end)
    end
  end

  defp revision_frontiers(conn) do
    sources = [
      {"inbox", "authenticated_inboxes"},
      {"policy", "root_policies"},
      {"control", "root_controls"},
      {"ledger", "root_ledgers"},
      {"reservation", "root_reservations"},
      {"effect", "root_effects"},
      {"claim", "root_claims"},
      {"lease", "root_leases"}
    ]

    Enum.reduce_while(sources, {:ok, %{}}, fn {name, table}, {:ok, acc} ->
      case Database.query(conn, "SELECT coalesce(max(revision), -1) FROM #{table}") do
        {:ok, [[revision]]} -> {:cont, {:ok, Map.put(acc, name, revision)}}
        {:error, _reason} = error -> {:halt, error}
        _ -> {:halt, {:error, :corrupt_revision_frontier}}
      end
    end)
  end

  defp command_fact(conn, id) do
    with {:ok, rows} <-
           Database.query(conn, "SELECT result FROM root_commands WHERE command_id = ?", [id]) do
      case rows do
        [[bytes]] -> decode(bytes)
        [] -> {:error, :not_found}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  defp pointer_fact(conn, kind)
       when kind in ["accepted_source", "selected_deployment", "healthy_build"] do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT pointer_kind, producer_status, revision, state FROM root_pointers WHERE pointer_kind = ?",
             [kind]
           ) do
      case rows do
        [[^kind, status, revision, bytes]] ->
          with {:ok, state} <- decode(bytes),
               true <- state["producer_status"] == status and state["revision"] == revision do
            {:ok, state}
          else
            _ -> {:error, :corrupt_root_pointer}
          end

        [] ->
          {:error, :root_pointer_missing}

        _ ->
          {:error, :duplicate_protected_identity}
      end
    end
  end

  defp pointer_fact(_conn, _kind), do: {:error, :unsupported_root_pointer}

  defp all_pointer_facts(conn) do
    Enum.reduce_while(
      ~w(accepted_source selected_deployment healthy_build),
      {:ok, %{}},
      fn kind, {:ok, acc} ->
        case pointer_fact(conn, kind) do
          {:ok, fact} -> {:cont, {:ok, Map.put(acc, kind, fact)}}
          {:error, _reason} = error -> {:halt, error}
        end
      end
    )
  end
end
