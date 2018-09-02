# TODO: Only for unit tests. Move to some place else.
defmodule ElixirSense.Providers.ReferencesTest.Callee do
  def func() do
    IO.puts ""
  end
  def func(par1) do
    IO.puts par1
  end
end
defmodule ElixirSense.Providers.ReferencesTest.Caller1 do
  def func() do
    ElixirSense.Providers.ReferencesTest.Callee.func()
  end
end
defmodule ElixirSense.Providers.ReferencesTest.Caller2 do
  def func() do
    ElixirSense.Providers.ReferencesTest.Callee.func("test")
  end
end
