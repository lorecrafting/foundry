defmodule Foundry.DurableStore.Protected.TransitionReplay do
  @moduledoc false

  alias Foundry.DurableStore.Database

  # Reopen-ready invariant: Operations writes states validated by RestartCheck and TransitionReplay.
  import Foundry.DurableStore.Protected.Rows

  @closed_effect_statuses Foundry.DurableStore.Protected.Rows.closed_effect_statuses()

  def validate_typed_transition_replay(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT operation, disposition, reason_code, canonical_request FROM root_commands ORDER BY seq"
           ),
         {:ok, replay} <- replay_transition_rows(rows),
         :ok <- validate_replay_ledgers(conn, replay.ledgers),
         :ok <- validate_replay_effects(conn, replay.effects),
         :ok <- validate_replay_claims(conn, replay.claims),
         :ok <- validate_replay_reservations(conn, replay.reservations),
         :ok <- validate_replay_closures(conn, replay.closures) do
      :ok
    end
  end

  defp replay_transition_rows(rows) do
    initial = %{
      ledgers: %{},
      effects: %{},
      claims: %{},
      reservations: %{},
      receipts: %{},
      closures: MapSet.new()
    }

    Enum.reduce_while(rows, {:ok, initial}, fn
      [type, disposition, reason, request_bytes], {:ok, replay} ->
        with {:ok, %{"request" => %{"operation" => operation}}} <- decode(request_bytes),
             ^type <- operation["type"],
             {:ok, next} <- replay_transition_operation(replay, operation, disposition, reason) do
          {:cont, {:ok, next}}
        else
          {:error, _reason} = error -> {:halt, error}
          _ -> {:halt, {:error, :invalid_typed_transition_history}}
        end
    end)
  end

  defp replay_transition_operation(replay, _operation, "rejected", reason)
       when reason != "conflicting_receipt",
       do: {:ok, replay}

  defp replay_transition_operation(
         replay,
         %{"type" => "settle_claim", "claim_id" => claim_id},
         "rejected",
         "conflicting_receipt"
       ) do
    with {:ok, claim} <- replay_get(replay.claims, claim_id),
         {:ok, effect} <- replay_get(replay.effects, claim.effect_id) do
      {:ok,
       replay
       |> put_in([:claims, claim_id], replay_status(claim, "reconciliation_required"))
       |> put_in([:effects, claim.effect_id], replay_status(effect, "reconciliation_required"))}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "grant_ledger"} = op, "accepted", _) do
    ledger =
      replay_ledger(op["ledger_id"], op["generation"], nil, nil, op["dimension"], op["units"])

    replay_add(replay, :ledgers, {op["ledger_id"], op["generation"]}, ledger)
  end

  defp replay_transition_operation(replay, %{"type" => "delegate_allocation"} = op, "accepted", _) do
    parent_key = {op["parent_ledger_id"], op["parent_generation"]}
    child_key = {op["child_ledger_id"], op["child_generation"]}

    with {:ok, parent} <- replay_get(replay.ledgers, parent_key),
         false <- Map.has_key?(replay.ledgers, child_key) do
      units = op["units"]

      parent =
        parent
        |> replay_revision()
        |> Map.update!(:available, &(&1 - units))
        |> Map.update!(:delegated, &(&1 + units))

      child =
        replay_ledger(
          op["child_ledger_id"],
          op["child_generation"],
          op["parent_ledger_id"],
          op["parent_generation"],
          parent.dimension,
          units
        )

      {:ok,
       replay
       |> put_in([:ledgers, parent_key], parent)
       |> put_in([:ledgers, child_key], child)}
    else
      _ -> {:error, :invalid_delegate_replay}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "return_allocation"} = op, "accepted", _) do
    child_key = {op["child_ledger_id"], op["child_generation"]}

    with {:ok, child} <- replay_get(replay.ledgers, child_key),
         parent_key <- {child.parent_ledger_id, child.parent_generation},
         {:ok, parent} <- replay_get(replay.ledgers, parent_key) do
      units = op["units"]

      child =
        child
        |> replay_revision()
        |> Map.update!(:authorized, &(&1 - units))
        |> Map.update!(:available, &(&1 - units))

      parent =
        parent
        |> replay_revision()
        |> Map.update!(:delegated, &(&1 - units))
        |> Map.update!(:available, &(&1 + units))

      {:ok,
       replay
       |> put_in([:ledgers, child_key], child)
       |> put_in([:ledgers, parent_key], parent)}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "reserve"} = op, "accepted", _) do
    with {:ok, ledger} <- replay_get(replay.ledgers, {op["ledger_id"], op["generation"]}) do
      reservation = %{
        reservation_id: op["reservation_id"],
        ledger_id: op["ledger_id"],
        generation: op["generation"],
        dimension: ledger.dimension,
        owner_kind: op["owner_kind"],
        owner_id: op["owner_id"],
        units: op["units"],
        revision: 0,
        status: "proposed",
        claim_id: nil
      }

      replay_add(replay, :reservations, reservation.reservation_id, reservation)
    end
  end

  defp replay_transition_operation(
         replay,
         %{"type" => "release_reservation", "reservation_id" => id},
         "accepted",
         _
       ),
       do: replay_release_reservations(replay, [id])

  defp replay_transition_operation(replay, %{"type" => "close_attempt"} = op, "accepted", _) do
    key = {op["ticket_id"], op["attempt_id"]}

    settled? =
      replay.effects
      |> Map.values()
      |> Enum.filter(&({&1.ticket_id, &1.attempt_id} == key))
      |> Enum.all?(&(&1.status in @closed_effect_statuses))

    if settled? and not MapSet.member?(replay.closures, key),
      do: {:ok, %{replay | closures: MapSet.put(replay.closures, key)}},
      else: {:error, :invalid_attempt_closure_replay}
  end

  defp replay_transition_operation(replay, %{"type" => "create_effect"} = op, "accepted", _) do
    with false <- Map.has_key?(replay.effects, op["effect_id"]),
         false <- MapSet.member?(replay.closures, {op["ticket_id"], op["attempt_id"]}),
         {:ok, replay} <- replay_activate_reservations(replay, op["reservation_ids"]) do
      effect = %{
        effect_id: op["effect_id"],
        ticket_id: op["ticket_id"],
        attempt_id: op["attempt_id"],
        control_id: op["control_id"],
        reservation_ids: op["reservation_ids"],
        status: "pending",
        revision: 0
      }

      {:ok, put_in(replay, [:effects, effect.effect_id], effect)}
    else
      _ -> {:error, :invalid_effect_replay}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "claim_effect"} = op, "accepted", _) do
    with {:ok, effect} <- replay_get(replay.effects, op["effect_id"]),
         true <- effect.status == "pending",
         false <- Map.has_key?(replay.claims, op["claim_id"]),
         {:ok, replay} <- replay_bind_reservations(replay, effect.reservation_ids, op["claim_id"]) do
      claim = %{
        claim_id: op["claim_id"],
        effect_id: effect.effect_id,
        writer_epoch: op["writer_epoch"],
        status: "claimed",
        revision: 0
      }

      {:ok,
       replay
       |> put_in([:effects, effect.effect_id], replay_status(effect, "claimed"))
       |> put_in([:claims, claim.claim_id], claim)}
    else
      _ -> {:error, :invalid_claim_replay}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "reclaim_claim"} = op, "accepted", _) do
    with {:ok, claim} <- replay_get(replay.claims, op["claim_id"]),
         true <- claim.status == "claimed" and claim.writer_epoch == op["prior_writer_epoch"] do
      next = claim |> replay_revision() |> Map.put(:writer_epoch, op["new_writer_epoch"])
      {:ok, put_in(replay, [:claims, claim.claim_id], next)}
    else
      _ -> {:error, :invalid_reclaim_replay}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "issue_claim"} = op, "accepted", _) do
    with {:ok, claim} <- replay_get(replay.claims, op["claim_id"]),
         true <- claim.status == "claimed",
         {:ok, effect} <- replay_get(replay.effects, claim.effect_id),
         true <- effect.status == "claimed",
         {:ok, replay} <-
           replay_reservation_statuses(replay, effect.reservation_ids, "issued_unknown") do
      {:ok,
       replay
       |> put_in([:claims, claim.claim_id], replay_status(claim, "issued"))
       |> put_in([:effects, effect.effect_id], replay_status(effect, "issued"))}
    else
      _ -> {:error, :invalid_issue_replay}
    end
  end

  defp replay_transition_operation(replay, %{"type" => "cancel_effect"} = op, "accepted", _),
    do: replay_cancel_effect(replay, op["effect_id"], op["proof"])

  defp replay_transition_operation(replay, %{"type" => "settle_claim"} = op, "accepted", _),
    do: replay_settle_claim(replay, op)

  defp replay_transition_operation(replay, %{"type" => "close_generation"} = op, "accepted", _),
    do: replay_close_subtree(replay, {op["ledger_id"], op["generation"]})

  defp replay_transition_operation(replay, %{"type" => "reset_generation"} = op, "accepted", _) do
    old_key = {op["ledger_id"], op["old_generation"]}

    with {:ok, old} <- replay_get(replay.ledgers, old_key),
         {:ok, replay} <- replay_close_subtree(replay, old_key) do
      fresh =
        replay_ledger(
          op["ledger_id"],
          op["new_generation"],
          op["parent_ledger_id"],
          op["parent_generation"],
          old.dimension,
          op["units"]
        )

      replay = put_in(replay, [:ledgers, {fresh.ledger_id, fresh.generation}], fresh)

      if is_binary(op["parent_ledger_id"]) do
        parent_key = {op["parent_ledger_id"], op["parent_generation"]}

        with {:ok, parent} <- replay_get(replay.ledgers, parent_key) do
          parent =
            parent
            |> replay_revision()
            |> Map.update!(:available, &(&1 - op["units"]))
            |> Map.update!(:delegated, &(&1 + op["units"]))

          {:ok, put_in(replay, [:ledgers, parent_key], parent)}
        end
      else
        {:ok, replay}
      end
    end
  end

  defp replay_transition_operation(replay, %{"type" => "set_control"} = op, "accepted", _) do
    if get_in(op, ["value", "status"]) == "cancel_requested" do
      replay.effects
      |> Enum.filter(fn {_id, effect} -> effect.control_id == op["control_id"] end)
      |> Enum.sort()
      |> Enum.reduce_while({:ok, replay}, fn {id, effect}, {:ok, acc} ->
        case effect.status do
          "pending" -> replay_reduce(replay_cancel_effect(acc, id, "unissued"))
          "claimed" -> replay_reduce(replay_cancel_effect(acc, id, "issuer_quiescent"))
          _ -> {:cont, {:ok, acc}}
        end
      end)
    else
      {:ok, replay}
    end
  end

  defp replay_transition_operation(replay, %{"type" => type}, "accepted", _)
       when type in ["set_policy", "append_inbox", "seal_inbox"],
       do: {:ok, replay}

  defp replay_transition_operation(_replay, _operation, _disposition, _reason),
    do: {:error, :unsupported_typed_transition}

  defp replay_reduce({:ok, replay}), do: {:cont, {:ok, replay}}
  defp replay_reduce(error), do: {:halt, error}

  defp replay_ledger(id, generation, parent, parent_generation, dimension, units) do
    %{
      ledger_id: id,
      generation: generation,
      parent_ledger_id: parent,
      parent_generation: parent_generation,
      dimension: dimension,
      revision: 0,
      status: "open",
      authorized: units,
      available: units,
      held: 0,
      consumed: 0,
      delegated: 0,
      retired: 0
    }
  end

  defp replay_get(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :missing_replay_authority}
    end
  end

  defp replay_add(replay, kind, key, value) do
    if Map.has_key?(replay[kind], key),
      do: {:error, :duplicate_replay_authority},
      else: {:ok, put_in(replay, [kind, key], value)}
  end

  defp replay_revision(value), do: Map.update!(value, :revision, &(&1 + 1))
  defp replay_status(value, status), do: value |> replay_revision() |> Map.put(:status, status)

  defp replay_activate_reservations(replay, ids) do
    Enum.reduce_while(ids, {:ok, replay}, fn id, {:ok, acc} ->
      with {:ok, reservation} <- replay_get(acc.reservations, id),
           true <- reservation.status == "proposed",
           key <- {reservation.ledger_id, reservation.generation},
           {:ok, ledger} <- replay_get(acc.ledgers, key) do
        reservation = replay_status(reservation, "reserved")

        ledger =
          ledger
          |> replay_revision()
          |> Map.update!(:available, &(&1 - reservation.units))
          |> Map.update!(:held, &(&1 + reservation.units))

        {:cont,
         {:ok,
          acc
          |> put_in([:reservations, id], reservation)
          |> put_in([:ledgers, key], ledger)}}
      else
        _ -> {:halt, {:error, :invalid_reservation_activation_replay}}
      end
    end)
  end

  defp replay_bind_reservations(replay, ids, claim_id) do
    Enum.reduce_while(ids, {:ok, replay}, fn id, {:ok, acc} ->
      with {:ok, reservation} <- replay_get(acc.reservations, id),
           true <- reservation.status == "reserved" and is_nil(reservation.claim_id) do
        next = reservation |> replay_revision() |> Map.put(:claim_id, claim_id)
        {:cont, {:ok, put_in(acc, [:reservations, id], next)}}
      else
        _ -> {:halt, {:error, :invalid_reservation_binding_replay}}
      end
    end)
  end

  defp replay_reservation_statuses(replay, ids, status) do
    Enum.reduce_while(ids, {:ok, replay}, fn id, {:ok, acc} ->
      case replay_get(acc.reservations, id) do
        {:ok, reservation} ->
          {:cont, {:ok, put_in(acc, [:reservations, id], replay_status(reservation, status))}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp replay_release_reservations(replay, ids) do
    # Skips holds already released, as release_many does.
    ids
    |> Enum.reject(&(get_in(replay, [:reservations, &1, :status]) in ["released", "retired"]))
    |> Enum.reduce_while({:ok, replay}, fn id, {:ok, acc} ->
      with {:ok, reservation} <- replay_get(acc.reservations, id),
           key <- {reservation.ledger_id, reservation.generation},
           {:ok, ledger} <- replay_get(acc.ledgers, key) do
        target = if ledger.status == "open", do: "released", else: "retired"
        next_reservation = replay_status(reservation, target)

        next_ledger =
          if reservation.status == "proposed" do
            ledger
          else
            bucket = if ledger.status == "open", do: :available, else: :retired

            ledger
            |> replay_revision()
            |> Map.update!(:held, &(&1 - reservation.units))
            |> Map.update!(bucket, &(&1 + reservation.units))
          end

        {:cont,
         {:ok,
          acc
          |> put_in([:reservations, id], next_reservation)
          |> put_in([:ledgers, key], next_ledger)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp replay_cancel_effect(replay, effect_id, "control_ack") do
    with {:ok, _effect} <- replay_get(replay.effects, effect_id), do: {:ok, replay}
  end

  defp replay_cancel_effect(replay, effect_id, proof)
       when proof in ["unissued", "issuer_quiescent"] do
    with {:ok, effect} <- replay_get(replay.effects, effect_id),
         {:ok, replay} <- replay_release_reservations(replay, effect.reservation_ids) do
      replay = put_in(replay, [:effects, effect_id], replay_status(effect, "cancelled"))

      case Enum.find(replay.claims, fn {_id, claim} -> claim.effect_id == effect_id end) do
        nil -> {:ok, replay}
        {id, claim} -> {:ok, put_in(replay, [:claims, id], replay_status(claim, "cancelled"))}
      end
    end
  end

  defp replay_settle_claim(replay, op) do
    with {:ok, claim} <- replay_get(replay.claims, op["claim_id"]),
         {:ok, effect} <- replay_get(replay.effects, claim.effect_id),
         {:ok, digest} <- receipt_digest(op) do
      receipt_key = {op["receipt_id"], op["request_id"], digest}

      if Map.has_key?(replay.receipts, receipt_key) do
        {:ok, replay}
      else
        replay = put_in(replay, [:receipts, receipt_key], op["outcome"])

        cond do
          # stale_unknown_receipt: a later unknown is stored and changes no status.
          op["outcome"] == "unknown" and claim.status != "issued" ->
            {:ok, replay}

          op["outcome"] == "unknown" ->
            {:ok,
             replay
             |> put_in([:claims, claim.claim_id], replay_status(claim, "unknown"))
             |> put_in([:effects, effect.effect_id], replay_status(effect, "unknown"))}

          true ->
            with {:ok, replay} <-
                   replay_settle_reservations(replay, effect.reservation_ids, op["outcome"]) do
              {:ok,
               replay
               |> put_in([:claims, claim.claim_id], replay_status(claim, op["outcome"]))
               |> put_in([:effects, effect.effect_id], replay_status(effect, op["outcome"]))}
            end
        end
      end
    end
  end

  defp replay_settle_reservations(replay, ids, outcome) do
    Enum.reduce_while(ids, {:ok, replay}, fn id, {:ok, acc} ->
      with {:ok, reservation} <- replay_get(acc.reservations, id),
           key <- {reservation.ledger_id, reservation.generation},
           {:ok, ledger} <- replay_get(acc.ledgers, key) do
        {status, bucket} =
          if outcome in ["succeeded", "failed"] do
            {"consumed", :consumed}
          else
            if ledger.status == "open", do: {"released", :available}, else: {"retired", :retired}
          end

        next_reservation = replay_status(reservation, status)

        next_ledger =
          ledger
          |> replay_revision()
          |> Map.update!(:held, &(&1 - reservation.units))
          |> Map.update!(bucket, &(&1 + reservation.units))

        {:cont,
         {:ok,
          acc
          |> put_in([:reservations, id], next_reservation)
          |> put_in([:ledgers, key], next_ledger)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp replay_close_subtree(replay, root_key) do
    descendants =
      replay.ledgers
      |> Map.keys()
      |> Enum.filter(&replay_descendant?(replay.ledgers, &1, root_key))
      |> Enum.sort()

    with true <- descendants != [],
         {:ok, replay} <-
           Enum.reduce_while(descendants, {:ok, replay}, fn key, {:ok, acc} ->
             ledger = acc.ledgers[key]

             ids =
               acc.reservations
               |> Enum.filter(fn {_id, reservation} ->
                 {reservation.ledger_id, reservation.generation} == key and
                   reservation.status == "reserved"
               end)
               |> Enum.map(&elem(&1, 0))
               |> Enum.sort()

             result =
               if ledger.status == "open",
                 do: replay_release_reservations(acc, ids),
                 else: {:ok, acc}

             case result do
               {:ok, next} -> {:cont, {:ok, replay_cancel_released_owners(next, ids)}}
               error -> {:halt, error}
             end
           end) do
      replay =
        Enum.reduce(descendants, replay, fn key, acc ->
          ledger = acc.ledgers[key]

          if ledger.status == "open" do
            closed =
              ledger
              |> replay_revision()
              |> Map.put(:status, "closed")
              |> Map.update!(:retired, &(&1 + ledger.available))
              |> Map.put(:available, 0)

            put_in(acc, [:ledgers, key], closed)
          else
            acc
          end
        end)

      {:ok, replay}
    else
      _ -> {:error, :invalid_close_replay}
    end
  end

  defp replay_cancel_released_owners(replay, ids) do
    ids
    |> Enum.map(&replay.reservations[&1].owner_id)
    |> Enum.uniq()
    |> Enum.reduce(replay, fn effect_id, acc ->
      case acc.effects[effect_id] do
        %{status: status} = effect when status in ["pending", "claimed"] ->
          acc = put_in(acc, [:effects, effect_id], replay_status(effect, "cancelled"))

          case Enum.find(acc.claims, fn {_id, claim} -> claim.effect_id == effect_id end) do
            nil -> acc
            {id, claim} -> put_in(acc, [:claims, id], replay_status(claim, "cancelled"))
          end

        _ ->
          acc
      end
    end)
  end

  defp replay_descendant?(_ledgers, key, key), do: true

  defp replay_descendant?(ledgers, key, root) do
    case ledgers[key] do
      %{parent_ledger_id: parent, parent_generation: generation} when is_binary(parent) ->
        replay_descendant?(ledgers, {parent, generation}, root)

      _ ->
        false
    end
  end

  defp validate_replay_ledgers(conn, replay) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT ledger_id, generation, parent_ledger_id, parent_generation, dimension, revision, status, authorized, available, held, consumed, delegated, retired FROM root_ledgers"
           ) do
      values =
        Map.new(rows, fn row ->
          ledger = ledger_from_row(row)
          {{ledger.ledger_id, ledger.generation}, ledger}
        end)

      if values == replay,
        do: :ok,
        else: {:error, {:protected_corrupt, "root_ledgers", :typed_transition_replay}}
    end
  end

  defp validate_replay_effects(conn, replay) do
    with {:ok, rows} <- Database.query(conn, "SELECT effect_id FROM root_effects") do
      Enum.reduce_while(rows, :ok, fn [id], :ok ->
        with {:ok, current} <- load_effect(conn, id),
             %{status: status, revision: revision} <- replay[id],
             true <- current.status == status and current.revision == revision do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_effects", :typed_transition_replay}}}
        end
      end)
      |> then(fn result ->
        if result == :ok and length(rows) != map_size(replay),
          do: {:error, {:protected_corrupt, "root_effects", :missing_typed_transition}},
          else: result
      end)
    end
  end

  defp validate_replay_closures(conn, closures) do
    with {:ok, rows} <-
           Database.query(conn, "SELECT ticket_id, attempt_id FROM root_attempt_closures") do
      if MapSet.new(rows, fn [ticket_id, attempt_id] -> {ticket_id, attempt_id} end) == closures,
        do: :ok,
        else: {:error, {:protected_corrupt, "root_attempt_closures", :typed_transition_replay}}
    end
  end

  defp validate_replay_claims(conn, replay) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT claim_id, effect_id, writer_epoch, status, revision FROM root_claims"
           ) do
      values =
        Map.new(rows, fn row ->
          claim = claim_from_replay_row(row)
          {claim.claim_id, claim}
        end)

      if values == replay,
        do: :ok,
        else: {:error, {:protected_corrupt, "root_claims", :typed_transition_replay}}
    end
  end

  defp claim_from_replay_row([claim_id, effect_id, writer_epoch, status, revision]),
    do: %{
      claim_id: claim_id,
      effect_id: effect_id,
      writer_epoch: writer_epoch,
      status: status,
      revision: revision
    }

  defp validate_replay_reservations(conn, replay) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT reservation_id, ledger_id, generation, dimension, owner_kind, owner_id, units, revision, status, claim_id FROM root_reservations"
           ) do
      values =
        Map.new(rows, fn row ->
          reservation = reservation_from_row(row)
          {reservation.reservation_id, reservation}
        end)

      if values == replay,
        do: :ok,
        else: {:error, {:protected_corrupt, "root_reservations", :typed_transition_replay}}
    end
  end

  def validate_current_transition_provenance(conn) do
    with {:ok, rows} <-
           Database.query(
             conn,
             "SELECT seq, operation, disposition, canonical_request, result FROM root_commands ORDER BY seq"
           ),
         {:ok, snapshots} <- transition_snapshots(rows),
         :ok <- validate_current_ledger_snapshots(conn, snapshots.ledgers, rows),
         :ok <- validate_current_effect_snapshots(conn, snapshots.effects, rows),
         :ok <- validate_current_claim_snapshots(conn, snapshots.claims, rows) do
      :ok
    end
  end

  defp transition_snapshots(rows) do
    Enum.reduce_while(rows, {:ok, %{ledgers: %{}, effects: %{}, claims: %{}}}, fn
      [sequence, type, _disposition, _request, result_bytes], {:ok, acc} ->
        with {:ok, result} <- decode(result_bytes),
             {:ok, next} <-
               collect_typed_transition_snapshots(type, result["facts"], sequence, acc) do
          {:cont, {:ok, next}}
        else
          {:error, _reason} = error -> {:halt, error}
          _ -> {:halt, {:error, :invalid_transition_result}}
        end
    end)
  end

  # Results have an explicit operation schema. Only direct fact fields are authority
  # carriers; receipt payloads and other nested diagnostic/artifact maps are opaque.
  defp collect_typed_transition_snapshots(type, facts, sequence, acc) when is_map(facts) do
    schema =
      case type do
        "grant_ledger" ->
          %{"ledger" => {:singular, :ledger}}

        "delegate_allocation" ->
          %{"parent_ledger" => {:singular, :ledger}, "child_ledger" => {:singular, :ledger}}

        "return_allocation" ->
          %{"parent_ledger" => {:singular, :ledger}, "child_ledger" => {:singular, :ledger}}

        "reserve" ->
          %{"ledger" => {:singular, :ledger}, "reservation" => {:singular, :reservation}}

        "release_reservation" ->
          %{"ledger" => {:singular, :ledger}, "reservation" => {:singular, :reservation}}

        "close_generation" ->
          %{"ledgers" => {:plural, :ledger}}

        "reset_generation" ->
          %{
            "closed_generation" => {:singular, :ledger},
            "new_generation" => {:singular, :ledger},
            "parent_ledger" => {:singular, :ledger},
            # Reset closes the old generation's whole delegated subtree, like close_generation.
            "ledgers" => {:plural, :ledger}
          }

        "create_effect" ->
          %{
            "effect" => {:singular, :effect},
            "reservations" => {:plural, :reservation},
            "ledgers" => {:plural, :ledger}
          }

        "claim_effect" ->
          %{"claim" => {:singular, :claim}, "effect" => {:singular, :effect}}

        "reclaim_claim" ->
          %{"claim" => {:singular, :claim}}

        "issue_claim" ->
          %{"claim" => {:singular, :claim}, "effect" => {:singular, :effect}}

        "set_control" ->
          %{"ledgers" => {:plural, :ledger}}

        "cancel_effect" ->
          %{
            "claim" => {:singular, :claim},
            "effect" => {:singular, :effect},
            "ledgers" => {:plural, :ledger}
          }

        "settle_claim" ->
          %{
            "claim" => {:singular, :claim},
            "effect" => {:singular, :effect},
            "ledgers" => {:plural, :ledger}
          }

        _ ->
          %{}
      end

    known = Map.keys(schema)

    ignored =
      ~w(receipt attempted_receipt required_revisions lease_specs takeover transfer_kind control_status outstanding_claim_ids)

    with :ok <- validate_declared_transition_carriers(facts, schema),
         known_carriers <- known |> Enum.flat_map(&direct_transition_carriers(facts[&1])),
         :ok <-
           facts
           |> Map.drop(known ++ ignored)
           |> Map.values()
           |> Enum.flat_map(&direct_transition_carriers/1)
           |> Enum.reduce_while(:ok, fn carrier, :ok ->
             if carrier in known_carriers,
               do: {:cont, :ok},
               else: {:halt, {:error, :conflicting_typed_transition_carrier}}
           end) do
      known
      |> Enum.reduce_while({:ok, acc}, fn key, {:ok, nested} ->
        case collect_declared_transition_snapshots(facts[key], sequence, nested, schema[key]) do
          {:ok, next} -> {:cont, {:ok, next}}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp collect_typed_transition_snapshots(_type, _facts, _sequence, _acc),
    do: {:error, :invalid_transition_facts}

  defp validate_declared_transition_carriers(facts, schema) do
    Enum.reduce_while(schema, :ok, fn {key, declaration}, :ok ->
      case Map.fetch(facts, key) do
        :error ->
          {:cont, :ok}

        {:ok, value} ->
          case validate_declared_transition_carrier(value, declaration) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
      end
    end)
  end

  defp validate_declared_transition_carrier(value, {:singular, kind}) when is_map(value) do
    if transition_carrier_kind(value) == kind and declared_transition_shape?(value, kind),
      do: :ok,
      else: {:error, :invalid_singular_transition_carrier}
  end

  defp validate_declared_transition_carrier(_value, {:singular, _kind}),
    do: {:error, :invalid_singular_transition_carrier}

  defp validate_declared_transition_carrier(values, {:plural, kind}) when is_list(values) do
    with true <- Enum.all?(values, &(is_map(&1) and transition_carrier_kind(&1) == kind)),
         true <- Enum.all?(values, &declared_transition_shape?(&1, kind)),
         identities <- Enum.map(values, &transition_carrier_identity(&1, kind)),
         true <- Enum.all?(identities, &(not is_nil(&1))),
         true <- length(identities) == length(Enum.uniq(identities)) do
      :ok
    else
      _ -> {:error, :invalid_plural_transition_carrier}
    end
  end

  defp validate_declared_transition_carrier(_value, {:plural, _kind}),
    do: {:error, :invalid_plural_transition_carrier}

  defp declared_transition_shape?(value, :ledger),
    do:
      Map.keys(value) |> Enum.sort() ==
        Enum.sort(
          ~w(schema_version ledger_id generation parent_ledger_id parent_generation dimension revision status authorized available held consumed delegated retired)
        ) and value["schema_version"] == 1

  defp declared_transition_shape?(value, :reservation),
    do:
      Map.keys(value) |> Enum.sort() ==
        Enum.sort(
          ~w(schema_version reservation_id ledger_id generation dimension owner_kind owner_id units revision status claim_id)
        ) and value["schema_version"] == 1

  defp declared_transition_shape?(value, :claim),
    do:
      Map.keys(value) |> Enum.sort() ==
        Enum.sort(~w(schema_version claim_id effect_id writer_epoch status revision)) and
        value["schema_version"] == 1

  defp declared_transition_shape?(value, :effect),
    do:
      Map.keys(value) |> Enum.sort() ==
        Enum.sort(
          ~w(schema_version effect_id request_digest policy_id policy_revision control_id control_revision operation scope ticket_id attempt_id execution_id assignment_id role phase_generation operation_ordinal predecessor_effect_id request_id issuer channel profile deadline status revision reservation_ids lease_specs)
        ) and value["schema_version"] == 1

  defp transition_carrier_kind(%{"ledger_id" => _, "generation" => _, "authorized" => _}),
    do: :ledger

  defp transition_carrier_kind(%{"reservation_id" => _, "ledger_id" => _}), do: :reservation
  defp transition_carrier_kind(%{"claim_id" => _, "effect_id" => _}), do: :claim
  defp transition_carrier_kind(%{"effect_id" => _}), do: :effect
  defp transition_carrier_kind(_value), do: nil

  defp transition_carrier_identity(value, :ledger),
    do: {value["ledger_id"], value["generation"]}

  defp transition_carrier_identity(value, :reservation), do: value["reservation_id"]
  defp transition_carrier_identity(value, :claim), do: value["claim_id"]
  defp transition_carrier_identity(value, :effect), do: value["effect_id"]

  defp direct_transition_carriers(value) when is_map(value) do
    if transition_carrier?(value), do: [value], else: []
  end

  defp direct_transition_carriers(values) when is_list(values),
    do: Enum.filter(values, &transition_carrier?/1)

  defp direct_transition_carriers(_value), do: []

  defp transition_carrier?(value), do: not is_nil(transition_carrier_kind(value))

  defp collect_declared_transition_snapshots(nil, _sequence, acc, _declaration),
    do: {:ok, acc}

  defp collect_declared_transition_snapshots(value, sequence, acc, {:singular, _kind}),
    do: maybe_put_transition_snapshot(value, sequence, acc)

  defp collect_declared_transition_snapshots(values, sequence, acc, {:plural, _kind}) do
    Enum.reduce_while(values, {:ok, acc}, fn value, {:ok, nested} ->
      case maybe_put_transition_snapshot(value, sequence, nested) do
        {:ok, next} -> {:cont, {:ok, next}}
        error -> {:halt, error}
      end
    end)
  end

  defp maybe_put_transition_snapshot(
         %{"ledger_id" => id, "generation" => generation, "authorized" => _units} = fact,
         seq,
         acc
       )
       when is_binary(id) and is_integer(generation),
       do: put_transition_snapshot(acc, :ledgers, {id, generation}, fact, seq)

  defp maybe_put_transition_snapshot(%{"claim_id" => id, "effect_id" => _effect} = fact, seq, acc)
       when is_binary(id),
       do: put_transition_snapshot(acc, :claims, id, fact, seq)

  defp maybe_put_transition_snapshot(%{"effect_id" => id} = fact, seq, acc)
       when is_binary(id),
       do: put_transition_snapshot(acc, :effects, id, fact, seq)

  defp maybe_put_transition_snapshot(_fact, _seq, acc), do: {:ok, acc}

  defp put_transition_snapshot(acc, kind, key, fact, sequence) do
    revision = fact["revision"]
    current = get_in(acc, [kind, key])

    cond do
      not is_integer(revision) or revision < 0 ->
        {:error, :invalid_transition_revision}

      is_nil(current) or revision > current.fact["revision"] ->
        {:ok, put_in(acc, [kind, key], %{sequence: sequence, fact: fact})}

      revision == current.fact["revision"] and fact == current.fact ->
        {:ok, put_in(acc, [kind, key], %{sequence: sequence, fact: fact})}

      true ->
        {:error, {:conflicting_transition_result, kind, key}}
    end
  end

  defp validate_current_ledger_snapshots(conn, snapshots, rows) do
    with {:ok, ledger_rows} <-
           Database.query(
             conn,
             "SELECT ledger_id, generation, parent_ledger_id, parent_generation, dimension, revision, status, authorized, available, held, consumed, delegated, retired FROM root_ledgers"
           ) do
      Enum.reduce_while(ledger_rows, :ok, fn row, :ok ->
        current = public_ledger(ledger_from_row(row))

        case Map.get(snapshots, {current["ledger_id"], current["generation"]}) do
          %{sequence: sequence, fact: expected} ->
            valid =
              current == expected or
                (current["revision"] > expected["revision"] and
                   ledger_immutable_transition_fields(current) ==
                     ledger_immutable_transition_fields(expected) and
                   implicit_authority_transition_after?(conn, rows, sequence, current))

            if valid,
              do: {:cont, :ok},
              else: {:halt, {:error, {:protected_corrupt, "root_ledgers", :transition}}}

          _ ->
            {:halt, {:error, {:protected_corrupt, "root_ledgers", :missing_transition}}}
        end
      end)
    end
  end

  defp ledger_immutable_transition_fields(ledger),
    do:
      Map.take(
        ledger,
        ~w(schema_version ledger_id generation parent_ledger_id parent_generation dimension status authorized)
      )

  defp validate_current_effect_snapshots(conn, snapshots, rows) do
    with {:ok, effect_rows} <- Database.query(conn, "SELECT effect_id FROM root_effects") do
      Enum.reduce_while(effect_rows, :ok, fn [id], :ok ->
        with {:ok, effect} <- load_effect(conn, id),
             current <- public_effect(effect),
             %{sequence: sequence, fact: expected} <- Map.get(snapshots, id),
             true <-
               effect_transition_fields(current) == effect_transition_fields(expected) or
                 implicit_cancelled_snapshot?(conn, rows, sequence, effect, expected) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_effects", :transition}}}
        end
      end)
    end
  end

  defp effect_transition_fields(effect),
    do: Map.take(effect, ~w(effect_id status revision))

  defp validate_current_claim_snapshots(conn, snapshots, rows) do
    with {:ok, claim_rows} <- Database.query(conn, "SELECT claim_id FROM root_claims") do
      Enum.reduce_while(claim_rows, :ok, fn [id], :ok ->
        with {:ok, claim} <- load_claim(conn, id),
             current <- public_claim(claim),
             %{sequence: sequence, fact: expected} <- Map.get(snapshots, id),
             true <-
               current == expected or
                 implicit_cancelled_claim_snapshot?(conn, rows, sequence, claim, expected) do
          {:cont, :ok}
        else
          _ -> {:halt, {:error, {:protected_corrupt, "root_claims", :transition}}}
        end
      end)
    end
  end

  defp implicit_cancelled_snapshot?(conn, rows, sequence, effect, expected) do
    effect.status == "cancelled" and effect.revision == expected["revision"] + 1 and
      implicit_authority_transition_after?(conn, rows, sequence, effect)
  end

  defp implicit_cancelled_claim_snapshot?(conn, rows, sequence, claim, expected) do
    with true <- claim.status == "cancelled" and claim.revision == expected["revision"] + 1,
         {:ok, effect} <- load_effect(conn, claim.effect_id) do
      implicit_authority_transition_after?(conn, rows, sequence, effect)
    else
      _ -> false
    end
  end

  defp implicit_authority_transition_after?(conn, rows, sequence, authority) do
    Enum.any?(rows, fn
      [seq, type, "accepted", request_bytes, _result] when seq > sequence ->
        with {:ok, %{"request" => %{"operation" => operation}}} <- decode(request_bytes) do
          case type do
            "set_control" ->
              operation["control_id"] == Map.get(authority, :control_id) and
                get_in(operation, ["value", "status"]) == "cancel_requested"

            type when type in ["close_generation", "reset_generation"] ->
              authority_in_generation?(conn, authority, operation)

            _ ->
              false
          end
        else
          _ -> false
        end

      _ ->
        false
    end)
  end

  defp authority_in_generation?(conn, %{effect_id: effect_id}, operation) do
    case reservations_for_effect(conn, effect_id) do
      {:ok, reservations} ->
        Enum.any?(reservations, &reservation_in_generation?(conn, &1, operation))

      _ ->
        false
    end
  end

  defp authority_in_generation?(conn, ledger, operation) do
    ledger_in_generation?(
      conn,
      ledger["ledger_id"],
      ledger["generation"],
      operation["ledger_id"],
      operation["generation"] || operation["old_generation"]
    )
  end

  defp reservation_in_generation?(conn, reservation, operation),
    do:
      ledger_in_generation?(
        conn,
        reservation.ledger_id,
        reservation.generation,
        operation["ledger_id"],
        operation["generation"] || operation["old_generation"]
      )

  defp ledger_in_generation?(_conn, ledger_id, generation, ledger_id, generation), do: true

  defp ledger_in_generation?(conn, ledger_id, generation, ancestor_id, ancestor_generation) do
    case load_existing_ledger(conn, ledger_id, generation) do
      {:ok, %{parent_ledger_id: parent, parent_generation: parent_generation}}
      when is_binary(parent) ->
        ledger_in_generation?(conn, parent, parent_generation, ancestor_id, ancestor_generation)

      _ ->
        false
    end
  end
end
