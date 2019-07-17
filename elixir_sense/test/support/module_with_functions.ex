defmodule ElixirSenseExample.ModuleWithFunctions do
  def function_arity_zero do
    :return_value
  end

  def function_arity_one(_) do
    nil
  end

  defdelegate delegated_function, to: ElixirSenseExample.ModuleWithFunctions.DelegatedModule

  defmodule DelegatedModule do
    def delegated_function do
      nil
    end
  end
end
