defmodule Foundry.LaunchEligibilityTest do
  @moduledoc """
  The FR-01 launch policy as a pure leaf: subscription-only eligibility, no paid fallback,
  and a stable blocked reason for every malformed policy. Moved from
  `autonomous_launch_test.exs` (lines 86-148 there) when the daemon that called
  `LaunchEligibility` was deleted on 2026-09-23; the FR-09 design decides what calls it next.
  """
  use ExUnit.Case, async: true

  alias Foundry.LaunchEligibility

  @profile_name "subscription"
  @profiles %{
    @profile_name => %{
      "provider" => "test-provider",
      "account" => "test-account",
      "billing_class" => "subscription",
      "subscription_authorized" => true,
      "premium_authorized" => false,
      "automatic_roles" => ["developer", "reviewer", "pm"],
      "quota_status" => "available",
      "model" => "subscription/exact-model",
      "allowed_models" => ["subscription/exact-model"],
      "approval_mode" => "write",
      "reasoning" => "medium"
    }
  }

  test "eligibility fails closed for every role and each disallowed profile state" do
    for role <- [:developer, :reviewer, :pm],
        {name, profiles, workflow_state, expected_tag} <- disallowed_cases() do
      assert {:error, reason} =
               LaunchEligibility.resolve(profiles, name, role, workflow_state, now: 1_000)

      assert elem(reason, 0) == expected_tag
    end
  end

  test "the explicit subscription profile is eligible for each autonomous role" do
    for role <- [:developer, :reviewer, :pm] do
      assert {:ok, profile} =
               LaunchEligibility.resolve(@profiles, @profile_name, role, %{}, now: 1_000)

      assert profile.name == @profile_name
      assert profile.role == to_string(role)
      assert profile.billing_class == "subscription"
      assert profile.provider == "test-provider"
      assert profile.model == "subscription/exact-model"
    end

    expired = %{
      "provider_cooldowns" => %{@profile_name => %{"until_epoch" => 999}}
    }

    assert {:ok, _profile} =
             LaunchEligibility.resolve(@profiles, @profile_name, :developer, expired, now: 1_000)
  end

  test "malformed nested policy always returns a stable blocked reason" do
    for {_label, profiles, workflow_state} <- malformed_policy_cases(),
        role <- [:developer, :reviewer, :pm] do
      assert {:error, reason} =
               LaunchEligibility.resolve(
                 profiles,
                 @profile_name,
                 role,
                 workflow_state,
                 now: 1_000
               )

      assert LaunchEligibility.reason(reason) =~ ~r/(invalid|missing)/
    end
  end

  test "nil and arbitrary unknown profile keys return an unambiguous denial" do
    for {_label, profiles} <- unknown_profile_key_cases() do
      assert {:error, {:invalid_profile_field, @profile_name, "unknown field"} = reason} =
               LaunchEligibility.resolve(
                 profiles,
                 @profile_name,
                 :developer,
                 %{},
                 now: 1_000
               )

      assert LaunchEligibility.reason(reason) ==
               ~s(profile "subscription" has invalid unknown field configuration)
    end
  end

  test "public policy selectors are total over improper and nested Elixir terms" do
    malformed_terms = [false, :invalid, <<255>>, ["value" | :invalid], %URI{}]

    for term <- malformed_terms do
      assert {:error, _reason} =
               LaunchEligibility.select_profile(nil, term, :developer)

      assert {:error, _reason} =
               LaunchEligibility.resolve(term, @profile_name, :developer, %{}, now: 1_000)

      assert {:error, _reason} =
               LaunchEligibility.resolve(
                 @profiles,
                 @profile_name,
                 :developer,
                 %{"provider_cooldowns" => term},
                 now: 1_000
               )
    end

    assert {:error, _reason} =
             LaunchEligibility.resolve(
               @profiles,
               @profile_name,
               :developer,
               %{},
               [{:now, 1_000} | :invalid]
             )

    # Was asserted through AgentServer.init/1; the selector itself refuses the newline name.
    assert {:error, reason} =
             LaunchEligibility.select_profile("subscription\n", %{}, :developer)

    assert LaunchEligibility.reason(reason) ==
             "invalid explicit profile selection for developer"
  end

  defp disallowed_cases do
    paid =
      put_in(@profiles, [@profile_name], %{
        @profiles[@profile_name]
        | "billing_class" => "paid",
          "premium_authorized" => false
      })

    manual = put_in(@profiles, [@profile_name, "billing_class"], "manual")
    premium = put_in(@profiles, [@profile_name, "premium_authorized"], true)
    exhausted = put_in(@profiles, [@profile_name, "quota_status"], "exhausted")
    exhausted_flag = put_in(@profiles, [@profile_name, "exhausted"], true)
    unknown_quota = put_in(@profiles, [@profile_name, "quota_status"], "unknown")
    disallowed = put_in(@profiles, [@profile_name, "automatic_roles"], [])

    cooled = %{
      "provider_cooldowns" => %{@profile_name => %{"until_epoch" => 2_000}}
    }

    [
      {nil, %{}, %{}, :profile_required},
      {@profile_name, paid, %{}, :profile_not_subscription_authorized},
      {@profile_name, manual, %{}, :profile_not_subscription_authorized},
      {@profile_name, premium, %{}, :profile_not_subscription_authorized},
      {@profile_name, disallowed, %{}, :profile_not_authorized_for_role},
      {@profile_name, exhausted, %{}, :profile_quota_unavailable},
      {@profile_name, exhausted_flag, %{}, :profile_quota_unavailable},
      {@profile_name, unknown_quota, %{}, :profile_quota_unavailable},
      {@profile_name, @profiles, cooled, :profile_cooldown_active}
    ]
  end

  defp malformed_policy_cases do
    base_cases = [
      {"subscription-boolean",
       put_in(@profiles, [@profile_name, "subscription_authorized"], "true"), %{}},
      {"premium-boolean", put_in(@profiles, [@profile_name, "premium_authorized"], "true"), %{}},
      {"exhausted-boolean", put_in(@profiles, [@profile_name, "exhausted"], "true"), %{}},
      {"roles-shape", put_in(@profiles, [@profile_name, "automatic_roles"], false), %{}},
      {"roles-enum", put_in(@profiles, [@profile_name, "automatic_roles"], ["operator"]), %{}},
      {"roles-improper",
       put_in(@profiles, [@profile_name, "automatic_roles"], ["developer" | :invalid]), %{}},
      {"roles-nested-improper",
       put_in(@profiles, [@profile_name, "automatic_roles"], [["developer" | :invalid]]), %{}},
      {"quota-shape", put_in(@profiles, [@profile_name, "quota_status"], %{}), %{}},
      {"model-list", put_in(@profiles, [@profile_name, "allowed_models"], false), %{}},
      {"model-list-improper",
       put_in(
         @profiles,
         [@profile_name, "allowed_models"],
         ["subscription/exact-model" | :invalid]
       ), %{}},
      {"model-list-nested-improper",
       put_in(
         @profiles,
         [@profile_name, "allowed_models"],
         [["subscription/exact-model" | :invalid]]
       ), %{}},
      {"reasoning-enum", put_in(@profiles, [@profile_name, "reasoning"], "ultra"), %{}},
      {"approval-enum", put_in(@profiles, [@profile_name, "approval_mode"], "explicit"), %{}},
      {"billing-enum", put_in(@profiles, [@profile_name, "billing_class"], "unknown"), %{}},
      {"required-empty", put_in(@profiles, [@profile_name, "account"], ""), %{}},
      {"account-whitespace", put_in(@profiles, [@profile_name, "account"], "   "), %{}},
      {"account-newline", put_in(@profiles, [@profile_name, "account"], "test-account\n"), %{}},
      {"account-invalid-utf8", put_in(@profiles, [@profile_name, "account"], <<255>>), %{}},
      {"account-default", put_in(@profiles, [@profile_name, "account"], "default"), %{}},
      {"provider-whitespace", put_in(@profiles, [@profile_name, "provider"], " test"), %{}},
      {"provider-newline", put_in(@profiles, [@profile_name, "provider"], "test-provider\n"),
       %{}},
      {"provider-invalid-utf8", put_in(@profiles, [@profile_name, "provider"], <<255>>), %{}},
      {"model-newline",
       @profiles
       |> put_in([@profile_name, "model"], "subscription/exact-model\n")
       |> put_in([@profile_name, "allowed_models"], ["subscription/exact-model\n"]), %{}},
      {"model-invalid-utf8",
       @profiles
       |> put_in([@profile_name, "model"], <<255>>)
       |> put_in([@profile_name, "allowed_models"], [<<255>>]), %{}},
      {"fuzzy-model",
       @profiles
       |> put_in([@profile_name, "model"], "claude")
       |> put_in([@profile_name, "allowed_models"], ["claude"]), %{}},
      {"unknown-field", put_in(@profiles, [@profile_name, "credential"], "implicit"), %{}},
      {"profile-shape", %{@profile_name => false}, %{}},
      {"profile-entry-struct", %{@profile_name => %URI{}}, %{}},
      {"profiles-struct", %URI{}, %{}},
      {"profile-key", %{subscription: @profiles[@profile_name]}, %{}},
      {"profile-key-newline", %{"subscription\n" => @profiles[@profile_name]}, %{}},
      {"cooldown-container", @profiles, %{"provider_cooldowns" => []}},
      {"cooldown-container-struct", @profiles, %{"provider_cooldowns" => %URI{}}},
      {"cooldown-entry", @profiles,
       %{"provider_cooldowns" => %{@profile_name => %{"provider" => "test-provider"}}}},
      {"cooldown-entry-struct", @profiles, %{"provider_cooldowns" => %{@profile_name => %URI{}}}},
      {"cooldown-expiry", @profiles,
       %{"provider_cooldowns" => %{@profile_name => %{"until_epoch" => "later"}}}},
      {"cooldown-key-newline", @profiles,
       %{"provider_cooldowns" => %{"subscription\n" => %{"until_epoch" => 2_000}}}},
      {"cooldown-profile-newline", @profiles,
       %{
         "provider_cooldowns" => %{
           @profile_name => %{"until_epoch" => 2_000, "profile" => "subscription\n"}
         }
       }},
      {"cooldown-provider-newline", @profiles,
       %{
         "provider_cooldowns" => %{
           @profile_name => %{"until_epoch" => 2_000, "provider" => "test-provider\n"}
         }
       }},
      {"cooldown-reason-newline", @profiles,
       %{
         "provider_cooldowns" => %{
           @profile_name => %{"until_epoch" => 2_000, "reason" => "quota\n"}
         }
       }}
    ]

    unknown_cases =
      Enum.map(unknown_profile_key_cases(), fn {label, profiles} -> {label, profiles, %{}} end)

    base_cases ++ unknown_cases
  end

  defp unknown_profile_key_cases do
    [
      {"unknown-nil-key", profile_with_unknown_fields([{nil, :invalid}])},
      {"unknown-nil-mask",
       profile_with_unknown_fields([{nil, :invalid}, {"credential", "implicit"}])},
      {"unknown-tuple-key", profile_with_unknown_fields([{{:credential, 1}, :invalid}])},
      {"unknown-struct-key", profile_with_unknown_fields([{URI.parse("invalid"), :invalid}])},
      {"unknown-improper-list-key",
       profile_with_unknown_fields([{["credential" | :invalid], :invalid}])}
    ]
  end

  defp profile_with_unknown_fields(fields) do
    update_in(@profiles, [@profile_name], fn profile ->
      Enum.reduce(fields, profile, fn {field, value}, result -> Map.put(result, field, value) end)
    end)
  end
end
