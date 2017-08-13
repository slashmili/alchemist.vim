defmodule ElixirSense.Providers.ModulesTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Definition

  doctest Definition

  test "test all modules available modules are listed" do
    modules = ElixirSense.all_modules()
    assert "ElixirSense" in modules
    assert not "ElixirSense.Providers" in modules
    assert "ElixirSense.Providers.Definition" in modules
    assert ":kernel" in modules
  end

end
