defmodule ElixirSense.Providers.Expand do

  @moduledoc """
  Provider responsible for code expansion features.
  """

  alias ElixirSense.Core.Ast

  @type expanded_code_map :: %{
    expand_once: String.t,
    expand:  String.t,
    expand_partial: String.t,
    expand_all: String.t,
  }

  @doc """
  Returns a map containing the results of all different code expansion methods
  available (expand_once, expand, expand_partial and expand_all).
  """
  @spec expand_full(String.t, [module], [module], module) :: expanded_code_map
  def expand_full(code, requires, imports, module) do
    env =
      __ENV__
      |> Ast.add_requires_to_env(requires)
      |> Ast.add_imports_to_env(imports)
      |> Ast.set_module_for_env(module)

    try do
      {_, expr} = code |> Code.string_to_quoted
      %{
        expand_once:    expr |> Macro.expand_once(env)  |> Macro.to_string,
        expand:         expr |> Macro.expand(env)       |> Macro.to_string,
        expand_partial: expr |> Ast.expand_partial(env) |> Macro.to_string,
        expand_all:     expr |> Ast.expand_all(env)     |> Macro.to_string,
      }
    rescue
      e ->
        message = inspect(e)
        %{
          expand_once: message,
          expand: message,
          expand_partial: message,
          expand_all: message,
        }
    end
  end
end
