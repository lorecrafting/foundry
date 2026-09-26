defmodule Foundry.DurableStore.Protected.ReadSet do
  @moduledoc false

  alias Foundry.DurableStore.Database

  import Foundry.DurableStore.Protected.Rows

  @operation_types Foundry.DurableStore.Protected.Rows.operation_types()

  @doc false
  def required_bundle_prestate_revisions(conn, operation, prior_operations) do
    with {:ok, required} <- required_reads(conn, operation),
         {:ok, extra_keys} <- staged_prestate_keys(conn, operation, prior_operations) do
      Enum.reduce_while(extra_keys, {:ok, required}, fn key, {:ok, acc} ->
        case current_revision(conn, key) do
          {:ok, revision} -> {:cont, {:ok, Map.put(acc, key, revision)}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)
    end
  end

  defp staged_prestate_keys(
         conn,
         %{"type" => "settle_claim", "outcome" => "non_started", "claim_id" => claim_id},
         prior_operations
       ) do
    with %{"effect_id" => effect_id} <-
           Enum.find(prior_operations, fn op ->
             op["type"] == "claim_effect" and op["claim_id"] == claim_id
           end),
         {:ok, lineage, predecessor} <-
           staged_effect_lineage(conn, effect_id, prior_operations) do
      {:ok, ["settlement/" <> effect_id, lineage | predecessor]}
    else
      nil -> {:ok, []}
      _ -> {:error, :invalid_staged_settlement_dependency}
    end
  end

  defp staged_prestate_keys(_conn, _operation, _prior_operations), do: {:ok, []}

  defp staged_effect_lineage(conn, effect_id, prior_operations) do
    case Enum.find(prior_operations, fn op ->
           op["type"] == "create_effect" and op["effect_id"] == effect_id
         end) do
      effect when is_map(effect) ->
        with role when is_binary(role) <- get_in(effect, ["request", "role"]),
             generation when is_integer(generation) <-
               get_in(effect, ["request", "phase_generation"]),
             ticket_id when is_binary(ticket_id) <- effect["ticket_id"],
             attempt_id when is_binary(attempt_id) <- effect["attempt_id"] do
          owner = assignment_id(ticket_id, attempt_id, role)
          predecessor = optional_settlement_predecessor(effect["predecessor_effect_id"])
          {:ok, encoded_infrastructure_lineage_key(role, owner, generation), predecessor}
        else
          _ -> {:error, :invalid_staged_effect}
        end

      nil ->
        with {:ok, effect} <- load_effect(conn, effect_id) do
          {:ok, infrastructure_lineage_key(effect),
           optional_settlement_predecessor(effect.predecessor_effect_id)}
        end
    end
  end

  defp optional_settlement_predecessor(id) when is_binary(id), do: ["settlement/" <> id]
  defp optional_settlement_predecessor(_id), do: []

  defp subtree_read_keys(conn, ledger_id, generation) do
    with {:ok, ledgers} <- subtree_ledgers(conn, ledger_id, generation) do
      ledger_keys = Enum.map(ledgers, &ledger_key(&1.ledger_id, &1.generation))

      dependent =
        Enum.flat_map(ledgers, fn ledger ->
          generation_dependency_keys(conn, ledger.ledger_id, ledger.generation)
        end)

      {:ok, Enum.uniq(ledger_keys ++ dependent)}
    end
  end

  defp generation_dependency_keys(conn, ledger_id, generation) do
    case Database.query(
           conn,
           "SELECT reservation_id, owner_kind, owner_id, claim_id FROM root_reservations WHERE ledger_id = ? AND generation = ? AND status = 'reserved' ORDER BY reservation_id",
           [ledger_id, generation]
         ) do
      {:ok, rows} ->
        Enum.flat_map(rows, fn [reservation_id, owner_kind, owner_id, claim_id] ->
          claim_keys = if is_binary(claim_id), do: ["claim/" <> claim_id], else: []

          effect_keys =
            if owner_kind == "effect", do: effect_authority_keys(conn, owner_id), else: []

          ["reservation/" <> reservation_id | claim_keys ++ effect_keys]
        end)

      _ ->
        []
    end
  end

  defp effect_dependency_keys(conn, effect_id) do
    reservation_keys =
      case reservations_for_effect(conn, effect_id) do
        {:ok, values} -> Enum.flat_map(values, &full_reservation_keys/1)
        _ -> []
      end

    claim_keys =
      case Database.query(
             conn,
             "SELECT claim_id FROM root_claims WHERE effect_id = ? ORDER BY claim_id",
             [effect_id]
           ) do
        {:ok, rows} -> Enum.map(rows, fn [claim_id] -> "claim/" <> claim_id end)
        _ -> []
      end

    effect_authority_keys(conn, effect_id) ++ reservation_keys ++ claim_keys
  end

  def complete_read_set(conn, operation, supplied) do
    with {:ok, required} <- required_reads(conn, operation),
         {:ok, supplied} <- normalize_read_set(supplied),
         true <- Map.keys(required) |> Enum.sort() == Map.keys(supplied) |> Enum.sort(),
         true <- required == supplied do
      :ok
    else
      false ->
        case normalize_read_set(supplied) do
          {:ok, supplied} ->
            case required_reads(conn, operation) do
              {:ok, required} ->
                if Map.keys(required) |> Enum.sort() == Map.keys(supplied) |> Enum.sort(),
                  do: {:error, :stale_read_set},
                  else: {:error, :incomplete_read_set}

              error ->
                error
            end

          _ ->
            {:error, :incomplete_read_set}
        end

      {:error, _reason} = error ->
        error

      _ ->
        {:error, :incomplete_read_set}
    end
  end

  def required_reads(conn, %{"type" => type} = operation) when type in @operation_types do
    with {:ok, keys} <- operation_read_keys(conn, type, operation) do
      Enum.reduce_while(keys, {:ok, %{}}, fn key, {:ok, acc} ->
        case current_revision(conn, key) do
          {:ok, revision} -> {:cont, {:ok, Map.put(acc, key, revision)}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)
    end
  end

  def required_reads(_conn, _operation), do: {:ok, %{}}

  defp operation_read_keys(_conn, "set_policy", op),
    do: {:ok, ["policy/" <> to_string(op["policy_id"])]}

  defp operation_read_keys(conn, "set_control", op) do
    base = ["control/" <> to_string(op["control_id"])]

    if get_in(op, ["value", "status"]) == "cancel_requested" do
      with {:ok, rows} <-
             Database.query(
               conn,
               "SELECT effect_id FROM root_effects WHERE control_id = ? AND status IN ('pending', 'claimed', 'issued', 'unknown', 'reconciliation_required') ORDER BY effect_id",
               [op["control_id"]]
             ) do
        keys =
          Enum.flat_map(rows, fn [effect_id] ->
            ["effect/" <> effect_id | effect_dependency_keys(conn, effect_id)]
          end)

        {:ok, Enum.uniq(base ++ keys)}
      end
    else
      {:ok, base}
    end
  end

  defp operation_read_keys(_conn, "append_inbox", op),
    do: {:ok, ["inbox/" <> to_string(op["execution_id"])]}

  defp operation_read_keys(_conn, "seal_inbox", op),
    do: {:ok, ["inbox/" <> to_string(op["execution_id"])]}

  defp operation_read_keys(_conn, "grant_ledger", op),
    do: {:ok, [ledger_key(op["ledger_id"], op["generation"])]}

  defp operation_read_keys(_conn, "delegate_allocation", op),
    do:
      {:ok,
       [
         ledger_key(op["parent_ledger_id"], op["parent_generation"]),
         ledger_key(op["child_ledger_id"], op["child_generation"])
       ]}

  defp operation_read_keys(conn, "return_allocation", op) do
    child = ledger_key(op["child_ledger_id"], op["child_generation"])

    case load_ledger(conn, op["child_ledger_id"], op["child_generation"]) do
      {:ok, %{parent_ledger_id: parent, parent_generation: generation}}
      when is_binary(parent) ->
        {:ok, [child, ledger_key(parent, generation)]}

      _ ->
        {:ok, [child]}
    end
  end

  defp operation_read_keys(_conn, "reserve", op),
    do:
      {:ok,
       [
         ledger_key(op["ledger_id"], op["generation"]),
         "reservation/" <> to_string(op["reservation_id"])
       ]}

  defp operation_read_keys(conn, "release_reservation", op),
    do: {:ok, reservation_dependency_keys(conn, op["reservation_id"])}

  defp operation_read_keys(conn, "close_generation", op),
    do: subtree_read_keys(conn, op["ledger_id"], op["generation"])

  defp operation_read_keys(conn, "reset_generation", op) do
    base =
      [
        ledger_key(op["ledger_id"], op["old_generation"]),
        ledger_key(op["ledger_id"], op["new_generation"])
      ] ++
        if(is_binary(op["parent_ledger_id"]),
          do: [ledger_key(op["parent_ledger_id"], op["parent_generation"])],
          else: []
        )

    with {:ok, subtree} <- subtree_read_keys(conn, op["ledger_id"], op["old_generation"]) do
      {:ok, Enum.uniq(base ++ subtree)}
    end
  end

  defp operation_read_keys(conn, "close_attempt", op) do
    with {:ok, effects} <-
           attempt_effects(
             conn,
             to_string(op["scope"]),
             to_string(op["ticket_id"]),
             to_string(op["attempt_id"])
           ) do
      {:ok,
       [closure_key(op["ticket_id"], op["attempt_id"])] ++
         Enum.map(effects, &("effect/" <> &1.effect_id)) ++
         Enum.flat_map(effects, fn effect ->
           Enum.map(Map.get(effect, :reservation_ids, []), &("reservation/" <> &1))
         end)}
    end
  end

  defp operation_read_keys(conn, "create_effect", op) do
    base = [
      closure_key(op["ticket_id"], op["attempt_id"]),
      "effect/" <> to_string(op["effect_id"]),
      "policy/" <> to_string(op["policy_id"]),
      "control/" <> to_string(op["control_id"])
      | Enum.map(op["reservation_ids"] || [], &("reservation/" <> to_string(&1)))
    ]

    reservation_keys =
      Enum.flat_map(op["reservation_ids"] || [], &reservation_dependency_keys(conn, &1))

    lease_keys =
      Enum.map(op["leases"] || [], fn lease ->
        id = Map.get(lease, "lease_id", Map.get(lease, :lease_id))
        "lease/" <> to_string(id)
      end)

    {:ok, Enum.uniq(base ++ reservation_keys ++ lease_keys)}
  end

  defp operation_read_keys(conn, "claim_effect", op) do
    reservations =
      case reservations_for_effect(conn, op["effect_id"]) do
        {:ok, values} -> Enum.flat_map(values, &full_reservation_keys/1)
        _ -> []
      end

    authority = effect_authority_keys(conn, op["effect_id"])

    {:ok,
     Enum.uniq([
       "effect/" <> to_string(op["effect_id"]),
       "claim/" <> to_string(op["claim_id"])
       | authority ++ reservations
     ])}
  end

  defp operation_read_keys(conn, "cancel_effect", op) do
    effect_key = "effect/" <> to_string(op["effect_id"])

    case load_effect(conn, op["effect_id"]) do
      {:ok, effect} ->
        reservation_keys =
          case reservations_for_effect(conn, effect.effect_id) do
            {:ok, values} -> Enum.flat_map(values, &full_reservation_keys/1)
            _ -> []
          end

        claim_keys =
          case Database.query(
                 conn,
                 "SELECT claim_id FROM root_claims WHERE effect_id = ? ORDER BY claim_id",
                 [effect.effect_id]
               ) do
            {:ok, rows} -> Enum.map(rows, fn [id] -> "claim/" <> id end)
            _ -> []
          end

        lease_keys = Enum.map(effect.lease_specs, &("lease/" <> &1["lease_id"]))
        authority_keys = ["policy/" <> effect.policy_id, "control/" <> effect.control_id]

        {:ok,
         Enum.uniq([effect_key | authority_keys ++ reservation_keys ++ claim_keys ++ lease_keys])}

      _ ->
        {:ok, [effect_key]}
    end
  end

  defp operation_read_keys(conn, "settle_claim", op) do
    with {:ok, base} <- claim_operation_read_keys(conn, "settle_claim", op) do
      if op["outcome"] == "non_started" do
        case load_claim(conn, op["claim_id"]) do
          {:ok, claim} ->
            case load_effect(conn, claim.effect_id) do
              {:ok, effect} ->
                lineage = infrastructure_lineage_key(effect)
                settlement = "settlement/" <> effect.effect_id

                predecessor =
                  if is_binary(effect.predecessor_effect_id),
                    do: ["settlement/" <> effect.predecessor_effect_id],
                    else: []

                {:ok, Enum.uniq(base ++ [settlement, lineage] ++ predecessor)}

              _ ->
                {:ok, base}
            end

          _ ->
            {:ok, base}
        end
      else
        {:ok, base}
      end
    end
  end

  defp operation_read_keys(conn, type, op) when type in ["reclaim_claim", "issue_claim"],
    do: claim_operation_read_keys(conn, type, op)

  defp operation_read_keys(_conn, _type, _op), do: {:ok, []}

  defp claim_operation_read_keys(conn, type, op) do
    claim_key = "claim/" <> to_string(op["claim_id"])

    case load_claim(conn, op["claim_id"]) do
      {:ok, claim} ->
        effect_keys =
          case load_effect(conn, claim.effect_id) do
            {:ok, effect} ->
              [
                "effect/" <> effect.effect_id,
                "policy/" <> effect.policy_id,
                "control/" <> effect.control_id
              ] ++
                predecessor_read_keys(conn, effect) ++
                Enum.map(effect.lease_specs, &("lease/" <> &1["lease_id"]))

            _ ->
              []
          end

        reservation_keys =
          case reservations_for_claim(conn, claim.claim_id) do
            {:ok, values} -> Enum.flat_map(values, &full_reservation_keys/1)
            _ -> []
          end

        receipt_keys =
          if type == "settle_claim", do: ["receipt/" <> to_string(op["receipt_id"])], else: []

        {:ok, Enum.uniq([claim_key | effect_keys ++ reservation_keys ++ receipt_keys])}

      _ ->
        {:ok, [claim_key]}
    end
  end

  defp reservation_dependency_keys(conn, id) do
    base = ["reservation/" <> to_string(id)]

    case load_reservation(conn, id) do
      {:ok, reservation} -> base ++ reservation_keys(reservation)
      _ -> base
    end
  end

  defp reservation_keys(reservation) do
    claim_keys = if reservation.claim_id, do: ["claim/" <> reservation.claim_id], else: []
    [ledger_key(reservation.ledger_id, reservation.generation) | claim_keys]
  end

  defp full_reservation_keys(reservation),
    do: ["reservation/" <> reservation.reservation_id | reservation_keys(reservation)]

  defp effect_authority_keys(conn, effect_id) do
    case load_effect(conn, effect_id) do
      {:ok, effect} ->
        [
          "effect/" <> effect.effect_id,
          "policy/" <> effect.policy_id,
          "control/" <> effect.control_id
        ] ++
          predecessor_read_keys(conn, effect) ++
          Enum.map(effect.lease_specs, &("lease/" <> &1["lease_id"]))

      _ ->
        ["effect/" <> to_string(effect_id)]
    end
  end

  defp predecessor_read_keys(conn, effect), do: predecessor_read_keys(conn, effect, MapSet.new())

  defp predecessor_read_keys(conn, %{predecessor_effect_id: id}, seen)
       when is_binary(id) do
    if MapSet.member?(seen, id) do
      ["effect/" <> id]
    else
      case load_effect(conn, id) do
        {:ok, predecessor} ->
          ["effect/" <> id | predecessor_read_keys(conn, predecessor, MapSet.put(seen, id))]

        _ ->
          ["effect/" <> id]
      end
    end
  end

  defp predecessor_read_keys(_conn, _effect, _seen), do: []

  defp current_revision(conn, "policy/" <> id),
    do: simple_revision(conn, "root_policies", "policy_id", id)

  defp current_revision(conn, "control/" <> id),
    do: simple_revision(conn, "root_controls", "control_id", id)

  defp current_revision(conn, "inbox/" <> id),
    do: simple_revision(conn, "authenticated_inboxes", "execution_id", id)

  defp current_revision(conn, "reservation/" <> id),
    do: simple_revision(conn, "root_reservations", "reservation_id", id)

  defp current_revision(conn, "effect/" <> id),
    do: simple_revision(conn, "root_effects", "effect_id", id)

  defp current_revision(conn, "claim/" <> id),
    do: simple_revision(conn, "root_claims", "claim_id", id)

  defp current_revision(conn, "lease/" <> id),
    do: simple_revision(conn, "root_leases", "lease_id", id)

  defp current_revision(conn, "receipt/" <> id) do
    with :ok <- identity(id),
         {:ok, rows} <-
           Database.query(conn, "SELECT 1 FROM root_receipts WHERE receipt_id = ?", [id]) do
      case rows do
        [] -> {:ok, "absent"}
        [[1]] -> {:ok, 0}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  defp current_revision(conn, "settlement/" <> id) do
    with :ok <- identity(id),
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT 1 FROM root_infrastructure_settlements WHERE effect_id = ?",
             [id]
           ) do
      case rows do
        [] -> {:ok, "absent"}
        [[1]] -> {:ok, 0}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  defp current_revision(conn, "infrastructure/" <> encoded) do
    with [role64, owner64, generation_text] <- String.split(encoded, "/", parts: 3),
         {:ok, role} <- Base.url_decode64(role64, padding: false),
         {:ok, owner} <- Base.url_decode64(owner64, padding: false),
         {generation, ""} when generation >= 0 <- Integer.parse(generation_text),
         {:ok, [[count]]} <-
           Database.query(
             conn,
             "SELECT count(*) FROM root_infrastructure_settlements WHERE role = ? AND work_owner = ? AND infrastructure_generation = ?",
             [role, owner, generation]
           ) do
      {:ok, count}
    else
      _ -> {:error, :invalid_read_set_key}
    end
  end

  defp current_revision(conn, "ledger/" <> rest) do
    case String.split(rest, "/", parts: 2) do
      [id, generation] ->
        case Integer.parse(generation) do
          {generation, ""} -> ledger_revision(conn, id, generation)
          _ -> {:error, :invalid_read_set_key}
        end

      _ ->
        {:error, :invalid_read_set_key}
    end
  end

  defp current_revision(conn, "closure/" <> encoded) do
    with [ticket64, attempt64] <- String.split(encoded, "/", parts: 2),
         {:ok, ticket_id} <- Base.url_decode64(ticket64, padding: false),
         {:ok, attempt_id} <- Base.url_decode64(attempt64, padding: false),
         {:ok, rows} <-
           Database.query(
             conn,
             "SELECT 1 FROM root_attempt_closures WHERE ticket_id = ? AND attempt_id = ?",
             [ticket_id, attempt_id]
           ) do
      case rows do
        [] -> {:ok, "absent"}
        [[1]] -> {:ok, 0}
        _ -> {:error, :duplicate_protected_identity}
      end
    else
      _ -> {:error, :invalid_read_set_key}
    end
  end

  defp current_revision(_conn, _key), do: {:error, :invalid_read_set_key}

  defp closure_key(ticket_id, attempt_id) do
    "closure/" <>
      Base.url_encode64(to_string(ticket_id), padding: false) <>
      "/" <> Base.url_encode64(to_string(attempt_id), padding: false)
  end

  defp infrastructure_lineage_key(effect) do
    encoded_infrastructure_lineage_key(
      effect.role,
      effect.assignment_id,
      effect.phase_generation
    )
  end

  defp encoded_infrastructure_lineage_key(role, owner, generation) do
    role = Base.url_encode64(role, padding: false)
    owner = Base.url_encode64(owner, padding: false)
    "infrastructure/#{role}/#{owner}/#{generation}"
  end

  defp simple_revision(conn, table, column, id) do
    with :ok <- identity(id),
         {:ok, rows} <-
           Database.query(conn, "SELECT revision FROM #{table} WHERE #{column} = ?", [id]) do
      case rows do
        [] -> {:ok, "absent"}
        [[revision]] -> {:ok, revision}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  defp ledger_revision(conn, id, generation) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT revision FROM root_ledgers WHERE ledger_id = ? AND generation = ?",
             [id, generation]
           ) do
      case rows do
        [] -> {:ok, "absent"}
        [[revision]] -> {:ok, revision}
        _ -> {:error, :duplicate_protected_identity}
      end
    end
  end

  def normalize_read_set(reads) when is_map(reads) and not is_struct(reads) do
    Enum.reduce_while(reads, {:ok, %{}}, fn
      {key, value}, {:ok, acc}
      when is_binary(key) and (value == "absent" or (is_integer(value) and value >= 0)) ->
        {:cont, {:ok, Map.put(acc, key, value)}}

      _item, _acc ->
        {:halt, {:error, :invalid_read_set}}
    end)
  end

  def normalize_read_set(_reads), do: {:error, :invalid_read_set}
  defp ledger_key(id, generation), do: "ledger/#{id}/#{generation}"
end
