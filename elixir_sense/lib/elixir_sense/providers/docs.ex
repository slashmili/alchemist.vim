defmodule ElixirSense.Providers.Docs do
  @moduledoc """
  Doc Provider
  """
  alias ElixirSense.Core.Introspection

  @spec all(String.t, [module], [{module, module}], module) :: {actual_mod_fun :: String.t, docs :: Introspection.docs}
  def all(subject, imports, aliases, module) do
    mod_fun =
      subject
      |> Introspection.split_mod_fun_call
      |> Introspection.actual_mod_fun(imports, aliases, module)
    {mod_fun_to_string(mod_fun), Introspection.get_all_docs(mod_fun)}
  end

  defp mod_fun_to_string({nil, fun}) do
    Atom.to_string(fun)
  end

  defp mod_fun_to_string({mod, nil}) do
    Introspection.module_to_string(mod)
  end

  defp mod_fun_to_string({mod, fun}) do
    Introspection.module_to_string(mod) <> "." <> Atom.to_string(fun)
  end

end
