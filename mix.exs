defmodule Foundry.MixProject do
  use Mix.Project

  def project do
    [
      app: :foundry,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      compilers: [:boundary] ++ Mix.compilers(),
      escript: [main_module: Foundry.ManualLane.CLI],
      releases: [foundry: [include_executables_for: [:unix], vm_args: "rel/vm.args"]],
      deps: [
        {:boundary, "~> 0.11", runtime: false},
        {:exqlite, "== 0.40.0"},
        {:owl, "~> 0.12"},
        {:sourceror, "~> 1.12", only: [:dev, :test], runtime: false}
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto, :public_key], mod: {Foundry.Application, []}]
  end
end
