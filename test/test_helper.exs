Code.require_file("support/kernel_harness.ex", __DIR__)

Foundry.Test.Harness.start()
ExUnit.after_suite(fn _results -> Foundry.Test.Harness.print_report() end)

ExUnit.start()
