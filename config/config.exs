import Config

operator_runtime_root =
  System.get_env("FOUNDRY_OPERATOR_RUNTIME_ROOT") ||
    if config_env() == :test do
      Path.join(System.tmp_dir!(), "foundry-test-operator")
    else
      Path.expand("../local", __DIR__)
    end

config :foundry, runtime_root: operator_runtime_root
