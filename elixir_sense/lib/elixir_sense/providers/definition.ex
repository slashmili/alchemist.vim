defmodule ElixirSense.Providers.Definition do

  @moduledoc """
  Provides a function to find out where symbols are defined.

  Currently finds definition of modules, functions and macros.
  """

  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.State.VarInfo

  defmodule Location do
    @type t :: %Location{
      found: boolean,
      type: :module | :function | :variable,
      file: String.t | nil,
      line: pos_integer | nil,
      column: pos_integer | nil
    }
    defstruct [:found, :type, :file, :line, :column]
  end

  @doc """
  Finds out where a module, function, macro or variable was defined.
  """
  @spec find(String.t, [module], [{module, module}], module, [%VarInfo{}]) :: %Location{}
  def find(subject, imports, aliases, module, vars) do
    var_info = vars |> Enum.find(fn %VarInfo{name: name} -> to_string(name) == subject end)
    case var_info do
      %VarInfo{positions: [{line, column}|_]} ->
        %Location{found: true, type: :variable, file: nil, line: line, column: column}
      _ ->
        subject
        |> Introspection.split_mod_fun_call
        |> Introspection.actual_mod_fun(imports, aliases, module)
        |> find_source()
    end
  end

  defp find_source({mod, fun}) do
    mod
    |> find_mod_file()
    |> find_fun_position(fun)
  end

  defp find_mod_file(module) do
    file = if Code.ensure_loaded? module do
      case module.module_info(:compile)[:source] do
        nil    -> nil
        source -> List.to_string(source)
      end
    end
    file = if file && File.exists?(file) do
      file
    else
      erl_file = module |> :code.which |> to_string |> String.replace(Regex.recompile!(~r/(.+)\/ebin\/([^\s]+)\.beam$/), "\\1/src/\\2.erl")
      if File.exists?(erl_file) do
        erl_file
      end
    end
    {module, file}
  end

  defp find_fun_position({_, file}, _fun) when file in ["non_existing", nil, ""] do
    %Location{found: false}
  end

  defp find_fun_position({mod, file}, fun) do

    type = case fun do
      nil -> :module
      _ -> :function
    end

    position = if String.ends_with?(file, ".erl") do
      find_fun_position_in_erl_file(file, fun)
    else
      file_metadata = Parser.parse_file(file, false, false, nil)
      Metadata.get_function_position(file_metadata, mod, fun)
    end

    case position do
      {line, column} -> %Location{found: true, type: type, file: file, line: line, column: column}
      _ -> %Location{found: true, type: type, file: file, line: 1, column: 1}
    end

  end

  defp find_fun_position_in_erl_file(file, fun) do
    fun_name = Atom.to_string(fun)
    index =
      file
      |> File.read!
      |> String.split(["\n", "\r\n"])
      |> Enum.find_index(&String.match?(&1, Regex.recompile!(~r/^#{fun_name}\b/)))

    {(index || 0) + 1, 1}
  end

end
