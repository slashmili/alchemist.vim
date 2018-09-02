defmodule ElixirSense.Providers.References do
  @moduledoc """
  This module provides References support by using
  the `Mix.Tasks.Xref.call/0` task to find all references to
  any function or module identified at the provided location.
  """

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.State.VarInfo

  def find(nil, _, _, _, _) do
    []
  end

  def find(subject, imports, aliases, module, scope, vars) do
    var_info = vars |> Enum.find(fn %VarInfo{name: name} -> to_string(name) == subject end)
    case var_info do
      %VarInfo{positions: positions} ->
        positions
        |> Enum.map(fn pos -> build_var_location(subject, pos) end)
      _ ->
        subject
        |> Introspection.split_mod_fun_call
        |> Introspection.actual_mod_fun(imports, aliases, module)
        |> xref_at_cursor(module, scope)
        |> Enum.map(&build_location/1)
        |> Enum.uniq()
    end
  end

  defp xref_at_cursor(actual_mod_fun, module, scope) do
    actual_mod_fun
    |> callee_at_cursor(module, scope)
    |> case do
      {:ok, mfa} -> callers(mfa)
      _ -> []
    end
  end

  defp callee_at_cursor({module, func}, module, {func, arity}) do
    {:ok, [module, func, arity]}
  end

  defp callee_at_cursor({module, func}, _module, _scope) do
    {:ok, [module, func]}
  end

  def callers(mfa), do: Mix.Tasks.Xref.calls() |> Enum.filter(caller_filter(mfa))

  defp caller_filter([module, func, arity]), do: &match?(%{callee: {^module, ^func, ^arity}}, &1)
  defp caller_filter([module, func]), do: &match?(%{callee: {^module, ^func, _}}, &1)
  defp caller_filter([module]), do: &match?(%{callee: {^module, _, _}}, &1)

  defp build_location(call) do
    %{
      uri: call.file,
      range: %{
        start: %{line: call.line, character: 0},
        end: %{line: call.line, character: 0}
      }
    }
  end

  defp build_var_location(subject, {line, column}) do
    %{
      uri: nil,
      range: %{
        start: %{line: line, character: column},
        end: %{line: line, character: column + String.length(subject)}
      }
    }
  end

end
