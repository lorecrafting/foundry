defmodule Foundry.BoundaryTest do
  use ExUnit.Case, async: true

  @forbidden_apps ~w(phoenix ecto postgrex oban libcluster broadway)a
  @forbidden_packages ~w(phoenix ecto postgrex oban libcluster broadway herdr openai anthropic)

  test "project is standalone, local, and release-capable" do
    project = Mix.Project.config()
    assert project[:releases][:foundry]
    assert node() == :nonode@nohost

    applications = Application.loaded_applications() |> Enum.map(&elem(&1, 0))
    assert Enum.all?(@forbidden_apps, &(&1 not in applications))
  end

  test "dependency manifests reject forbidden runtime classes" do
    mix = File.read!(Path.expand("../../mix.exs", __DIR__))
    lock = File.read!(Path.expand("../../mix.lock", __DIR__))
    downcased = String.downcase(mix <> lock)

    assert Enum.all?(@forbidden_packages, &(not String.contains?(downcased, ":#{&1}")))
  end

  test "the test node's application supervisor starts no runtime children" do
    assert Supervisor.which_children(Foundry.Supervisor) == []
  end
end
