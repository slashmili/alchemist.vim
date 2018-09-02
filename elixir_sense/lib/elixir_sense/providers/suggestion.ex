defmodule ElixirSense.Providers.Suggestion do

  @moduledoc """
  Provider responsible for finding suggestions for auto-completing
  """

  alias Alchemist.Helpers.Complete
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Source

  @type fun_arity :: {atom, non_neg_integer}
  @type scope :: module | fun_arity

  @type attribute :: %{
    type: :attribute,
    name: String.t
  }

  @type variable :: %{
    type: :var,
    name: String.t
  }

  @type field :: %{
    type: :field,
    name: String.t,
    origin: String.t,
  }

  @type return :: %{
    type: :return,
    description: String.t,
    spec: String.t,
    snippet: String.t,
  }

  @type callback :: %{
    type: :callback,
    name: String.t,
    arity: non_neg_integer,
    args: String.t,
    origin: String.t,
    summary: String.t,
    spec: String.t
  }

  @type func :: %{
    type: :function,
    name: String.t,
    arity: non_neg_integer,
    args: String.t,
    origin: String.t,
    summary: String.t,
    spec: String.t
  }

  @type mod :: %{
    type: :module,
    name: String.t,
    subtype: String.t,
    summary: String.t
  }

  @type hint :: %{
    type: :hint,
    value: String.t
  }

  @type suggestion :: attribute
                    | variable
                    | field
                    | return
                    | callback
                    | func
                    | mod
                    | hint

  @doc """
  Finds all suggestions for a hint based on context information.
  """
  @spec find(String.t, [module], [{module, module}], module, [String.t], [String.t], [module], scope, String.t) :: [suggestion]
  def find(hint, imports, aliases, module, vars, attributes, behaviours, scope, text_before) do
    case find_struct_fields(hint, text_before, imports, aliases, module) do
      [] ->
        find_all_except_struct_fields(hint, imports, aliases, vars, attributes, behaviours, scope)
      fields ->
        [%{type: :hint, value: "#{hint}"} | fields]
    end
  end

  @spec find_all_except_struct_fields(String.t, [module], [{module, module}], [String.t], [String.t], [module], scope) :: [suggestion]
  defp find_all_except_struct_fields(hint, imports, aliases, vars, attributes, behaviours, scope) do
    vars = Enum.map(vars, fn v -> v.name end)
    %{hint: hint_suggestion, suggestions: mods_and_funcs} = find_hint_mods_funcs(hint, imports, aliases)

    callbacks_or_returns =
      case scope do
        {_f, _a} -> find_returns(behaviours, hint, scope)
        _mod   -> find_callbacks(behaviours, hint)
      end

    [hint_suggestion]
    |> Kernel.++(callbacks_or_returns)
    |> Kernel.++(find_attributes(attributes, hint))
    |> Kernel.++(find_vars(vars, hint))
    |> Kernel.++(mods_and_funcs)
    |> Enum.uniq_by(&(&1))
  end

  defp find_struct_fields(hint, text_before, imports, aliases, module) do
    with \
      {mod, fields_so_far} <- Source.which_struct(text_before),
      {actual_mod, _}      <- Introspection.actual_mod_fun({mod, nil}, imports, aliases, module),
      true                 <- Introspection.module_is_struct?(actual_mod)
    do
      actual_mod
      |> struct()
      |> Map.from_struct()
      |> Map.keys()
      |> Kernel.--(fields_so_far)
      |> Enum.filter(fn field -> String.starts_with?("#{field}", hint)end)
      |> Enum.map(fn field -> %{type: :field, name: field, origin: Introspection.module_to_string(actual_mod)} end)
    else
      _ -> []
    end
  end

  @spec find_hint_mods_funcs(String.t, [module], [{module, module}]) :: %{hint: hint, suggestions: [mod | func]}
  defp find_hint_mods_funcs(hint, imports, aliases) do
    Application.put_env(:"alchemist.el", :aliases, aliases)

    list1 = Complete.run(hint, imports)
    list2 = Complete.run(hint)

    {hint_suggestion, suggestions} =
      case List.first(list2) do
        %{type: :hint} = sug ->
          {sug, list1 ++ List.delete_at(list2, 0)}
        _ ->
          {%{type: :hint, value: "#{hint}"}, list1 ++ list2}
      end

    %{hint: hint_suggestion, suggestions: suggestions}
  end

  @spec find_vars([String.t], String.t) :: [variable]
  defp find_vars(vars, hint) do
    for var <- vars, hint == "" or String.starts_with?("#{var}", hint) do
      %{type: :variable, name: var}
    end |> Enum.sort
  end

  @spec find_attributes([String.t], String.t) :: [attribute]
  defp find_attributes(attributes, hint) do
    for attribute <- attributes, hint in ["", "@"] or String.starts_with?("@#{attribute}", hint) do
      %{type: :attribute, name: "@#{attribute}"}
    end |> Enum.sort
  end

  @spec find_returns([module], String.t, scope) :: [return]
  defp find_returns(behaviours, "", {fun, arity}) do
    for mod <- behaviours, Introspection.define_callback?(mod, fun, arity) do
      for return <- Introspection.get_returns_from_callback(mod, fun, arity) do
        %{type: :return, description: return.description, spec: return.spec, snippet: return.snippet}
      end
    end |> List.flatten
  end
  defp find_returns(_behaviours, _hint, _module) do
    []
  end

  @spec find_callbacks([module], String.t) :: [callback]
  defp find_callbacks(behaviours, hint) do
    behaviours |> Enum.flat_map(fn mod ->
      mod_name = mod |> Introspection.module_to_string
      for %{name: name, arity: arity, callback: spec, signature: signature, doc: doc} <- Introspection.get_callbacks_with_docs(mod),
          hint == "" or String.starts_with?("#{name}", hint)
      do
        desc = Introspection.extract_summary_from_docs(doc)
        [_, args_str] = Regex.run(Regex.recompile!(~r/.\((.*)\)/), signature)
        args = args_str |> String.replace(Regex.recompile!(~r/\s/), "")
        %{type: :callback, name: name, arity: arity, args: args, origin: mod_name, summary: desc, spec: spec}
      end
    end) |> Enum.sort
  end

end
