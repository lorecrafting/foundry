defmodule Foundry.Test.LegacyProtectedRows do
  @moduledoc """
  Seeds the FR-07 legacy protected rows for one committed domain command.

  `Gateway.transact_verified/6` and `ProtectedVerifier`, the only writers of
  `ledger_generations`, `claims` and `reservations`, were deleted (ML-DEAD-ROUTES); the lane
  writes the `root_*` tables instead. `Authority` still reads, verifies and fences these
  tables in a retained store, so its read-side tests seed here exactly the rows the deleted
  route derived for `id`: one root generation of one unit, one claim on `effect-<id>` and one
  reservation funding it. Call it after `effect-<id>`'s command has committed.
  """

  alias Foundry.DurableStore.{Database, RecordCodec}

  def insert!(gateway, id, writer_epoch \\ "epoch") do
    conn = :sys.get_state(gateway).conn

    :ok =
      Database.execute(
        conn,
        "INSERT INTO ledger_generations(generation_id, parent_generation_id, schema_version, revision, allocation, consumed) VALUES (?, NULL, 1, 0, 1, 0)",
        ["generation-#{id}"]
      )

    {:ok, claim} =
      RecordCodec.encode(:claim, %{
        schema_version: 1,
        claim_id: "claim-#{id}",
        effect_id: "effect-#{id}",
        writer_epoch: writer_epoch,
        status: "claimed",
        value: %{"verified" => true}
      })

    :ok =
      Database.execute(
        conn,
        "INSERT INTO claims(claim_id, effect_id, writer_epoch, status, claim) VALUES (?, ?, ?, 'claimed', ?)",
        ["claim-#{id}", "effect-#{id}", writer_epoch, {:blob, claim}]
      )

    {:ok, reservation} =
      RecordCodec.encode(:reservation, %{
        schema_version: 1,
        reservation_id: "reservation-#{id}",
        generation_id: "generation-#{id}",
        claim_id: "claim-#{id}",
        dimension: "starts.developer",
        units: 1,
        status: "reserved",
        value: %{"verified" => true}
      })

    :ok =
      Database.execute(
        conn,
        "INSERT INTO reservations(reservation_id, generation_id, claim_id, dimension, units, status, reservation) VALUES (?, ?, ?, 'starts.developer', 1, 'reserved', ?)",
        ["reservation-#{id}", "generation-#{id}", "claim-#{id}", {:blob, reservation}]
      )
  end
end
