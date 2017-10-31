defmodule ElixirSense.Providers.Definition do

  @moduledoc """
  Provides a function to find out where symbols are defined.

  Currently finds definition of modules, functions and macros.
  """

  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Introspection

  @type file :: String.t
  @type line :: pos_integer
  @type location :: {file, line | nil}

  @doc """
  Finds out where a module, function or macro was defined.
  """
  @spec find(String.t, [module], [{module, module}], module) :: location
  def find(subject, imports, aliases, module) do
    subject
    |> Introspection.split_mod_fun_call
    |> Introspection.actual_mod_fun(imports, aliases, module)
    |> find_source()
  end

  defp find_source({mod, fun}) do
    mod
    |> find_mod_file()
    |> find_fun_line(fun)
  end

  defp find_mod_file(module) do
    file = if Code.ensure_loaded? module do
      case module.module_info(:compile)[:source] do
        nil    -> nil
        source -> List.to_string(source)
      end
    end
    {file, exists?} = if file do
      {file, File.exists?(file)}
    else
      erl_file = module |> :code.which |> to_string |> String.replace(Regex.recompile!(~r/(.+)\/ebin\/([^\s]+)\.beam$/), "\\1/src/\\2.erl")
      {erl_file, File.exists?(erl_file)}
    end
    {module, file, exists?}
  end

  defp find_fun_line({_, file, _}, _fun) when file in ["non_existing", nil, ""] do
    {"non_existing", nil}
  end

  defp find_fun_line({_mod, file, false}, _fun) do
    {file, -1}
  end

  defp find_fun_line({mod, file, _}, fun) do
    line = if String.ends_with?(file, ".erl") do
      find_fun_line_in_erl_file(file, fun)
    else
      file_metadata = Parser.parse_file(file, false, false, nil)
      Metadata.get_function_line(file_metadata, mod, fun)
    end
    {file, line}
  end

  defp find_fun_line_in_erl_file(file, fun) do
    fun_name = Atom.to_string(fun)
    index =
      file
      |> File.read!
      |> String.split(["\n", "\r\n"])
      |> Enum.find_index(&String.match?(&1, Regex.recompile!(~r/^#{fun_name}\b/)))

    (index || 0) + 1
  end

end
