defmodule ElixirSense.Core.Metadata do
  @moduledoc """
  Core Metadata
  """

  alias ElixirSense.Core.State
  alias ElixirSense.Core.Introspection

  defstruct source: nil,
            mods_funs_to_lines: %{},
            lines_to_env: %{},
            error: nil

  def get_env(%__MODULE__{} = metadata, line_number) do
    case Map.get(metadata.lines_to_env, line_number) do
      nil -> %State.Env{}
      ctx -> ctx
    end
  end

  def get_function_line(%__MODULE__{} = metadata, module, function) do
    case Map.get(metadata.mods_funs_to_lines, {module, function, nil}) do
      nil -> get_function_line_using_docs(module, function)
      %{lines: lines} -> List.last(lines)
    end
  end

  def get_function_info(%__MODULE__{} = metadata, module, function) do
    case Map.get(metadata.mods_funs_to_lines, {module, function, nil}) do
      nil -> %{lines: [], params: []}
      info -> info
    end
  end

  def get_function_params(%__MODULE__{} = metadata, module, function) do
    params =
      metadata
      |> get_function_info(module, function)
      |> Map.get(:params)
      |> Enum.reverse

    Enum.map(params, fn param ->
      param
      |> Macro.to_string()
      |> String.slice(1..-2)
    end)
  end

  def get_function_signatures(%__MODULE__{} = metadata, module, function, code_docs \\ nil) do
    docs = code_docs || Code.get_docs(module, :docs) || []

    params_list =
      metadata
      |> get_function_info(module, function)
      |> Map.get(:params)
      |> Enum.reverse

    Enum.map(params_list, fn params ->
      arity = length(params)
      {doc, spec} =
        Enum.find_value(docs, {"", ""}, fn {{f, a}, _, _, _, text} ->
          f == function &&
          a == arity &&
          {Introspection.extract_summary_from_docs(text), Introspection.get_spec(module, function, arity)}
        end)
      %{name: Atom.to_string(function),
        params: params |> Enum.with_index() |> Enum.map(&Introspection.param_to_var/1),
        documentation: doc,
        spec: spec
      }
    end)
  end

  defp get_function_line_using_docs(module, function) do
    docs = Code.get_docs(module, :docs)

    for {{func, _arity}, line, _kind, _, _} <- docs, func == function do
      line
    end |> Enum.at(0)
  end

end
