defmodule PramanaFoundry.DurableStore.Kernel do
  @moduledoc "Bundle normalization above the fixed record codec: the Gateway's candidate check."

  alias PramanaFoundry.DurableStore.RecordCodec

  def normalize_bundle(bundle) do
    with {:ok, normalized} <- RecordCodec.normalize_bundle(bundle),
         :ok <- disposition_consistency(normalized) do
      {:ok, normalized}
    end
  end

  defp disposition_consistency(bundle) do
    if bundle["result"]["disposition"] in ["rejected", "blocked"] and
         Enum.any?(~w(events projections intents), &(bundle[&1] != [])),
       do: {:error, :rejected_result_has_domain_mutation},
       else: :ok
  end
end
