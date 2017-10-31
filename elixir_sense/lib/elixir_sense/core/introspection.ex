defmodule ElixirSense.Core.Introspection do
  @moduledoc """
  A collection of functions to introspect/format docs, specs, types and callbacks.

  Based on:
  https://github.com/elixir-lang/elixir/blob/c983b3db6936ce869f2668b9465a50007ffb9896/lib/iex/lib/iex/introspection.ex
  https://github.com/elixir-lang/ex_doc/blob/82463a56053b29a406fd271e9e2e2f05e87d6248/lib/ex_doc/retriever.ex
  """

  alias Kernel.Typespec
  alias Alchemist.Helpers.ModuleInfo

  @type mod_fun :: {mod :: module | nil, fun :: atom | nil}
  @type markdown :: String.t
  @type mod_docs :: %{docs: markdown, types: markdown, callbacks: markdown}
  @type fun_docs :: %{docs: markdown, types: markdown}
  @type docs :: mod_docs | fun_docs

  @wrapped_behaviours %{
    :gen_server  => GenServer,
    :gen_event   => GenEvent
  }

  def all_modules do
    ModuleInfo.all_applications_modules()
  end

  @spec get_all_docs(mod_fun) :: docs
  def get_all_docs({mod, nil}) do
    %{docs: get_docs_md(mod), types: get_types_md(mod), callbacks: get_callbacks_md(mod)}
  end

  def get_all_docs({mod, fun}) do
    %{docs: get_func_docs_md(mod, fun), types: get_types_md(mod)}
  end

  def get_signatures(mod, fun, code_docs \\ nil) do
    docs = code_docs || Code.get_docs(mod, :docs) || []
    for {{f, arity}, _, _, args, text} <- docs, f == fun do
      fun_args = Enum.map(args, &format_doc_arg(&1))
      fun_str = Atom.to_string(fun)
      doc = extract_summary_from_docs(text)
      spec = get_spec(mod, fun, arity)
      %{name: fun_str, params: fun_args, documentation: doc, spec: spec}
    end
  end

  def get_func_docs_md(mod, fun) do
    docs =
      case Code.get_docs(mod, :docs) do
        nil -> nil
        docs ->
          for {{f, arity}, _, _, args, text} <- docs, f == fun do
            fun_args_text = args
            |> Enum.map_join(", ", &format_doc_arg(&1))
            |> String.replace("\\\\", "\\\\\\\\")
            mod_str = module_to_string(mod)
            fun_str = Atom.to_string(fun)
            "> #{mod_str}.#{fun_str}(#{fun_args_text})\n\n#{get_spec_text(mod, fun, arity)}#{text}"
          end
      end

    case docs do
      [_|_] -> Enum.join(docs, "\n\n____\n\n")
      _ -> "No documentation available"
    end
  end

  def get_docs_md(mod) when is_atom(mod) do
    mod_str = module_to_string(mod)
    case Code.get_docs(mod, :moduledoc) do
      {_line, doc} when is_binary(doc) ->
        "> #{mod_str}\n\n" <> doc
      _ ->
        "No documentation available"
    end
  end

  def get_types_md(mod) when is_atom(mod) do
    for %{type: type, doc: doc} <- get_types_with_docs(mod) do
      """
        `#{type}`

        #{doc}
      """
    end |> Enum.join("\n\n____\n\n")
  end

  def get_callbacks_md(mod) when is_atom(mod) do
    for %{callback: callback, signature: signature, doc: doc} <- get_callbacks_with_docs(mod) do
      """
        > #{signature}

        ### Specs

        `#{callback}`

        #{doc}
      """
    end
    |> Enum.join("\n\n____\n\n")
  end

  def get_callbacks_with_docs(mod) when is_atom(mod) do
    mod =
      @wrapped_behaviours
      |> Map.get(mod, mod)

    case get_callbacks_and_docs(mod) do
      {callbacks, []} ->
        Enum.map(callbacks, fn {{name, arity}, [spec | _]} ->
          spec_ast = Typespec.spec_to_ast(name, spec)
          signature = get_typespec_signature(spec_ast, arity)
          definition = format_spec_ast(spec_ast)
          %{name: name, arity: arity, callback: "@callback #{definition}", signature: signature, doc: nil}
        end)
      {callbacks, docs} ->
        Enum.map docs, fn
          {{fun, arity}, _, :macrocallback, doc} ->
            fun
            |> get_callback_with_doc(:macrocallback, doc, {:"MACRO-#{fun}", arity + 1}, callbacks)
            |> Map.put(:arity, arity)
          {{fun, arity}, _, kind, doc} ->
            get_callback_with_doc(fun, kind, doc, {fun, arity}, callbacks)
        end
    end
  end

  def get_types_with_docs(module) when is_atom(module) do
    module
    |> get_types()
    |> Enum.map(fn {_, {t, _, _args}} = type ->
      %{type: format_type(type), doc: get_type_doc(module, t)}
    end)
  end

  defp get_types(module) when is_atom(module) do
    case Typespec.beam_types(module) do
      nil   -> []
      types -> types
    end
  end

  def extract_summary_from_docs(doc) when doc in [nil, "", false], do: ""
  def extract_summary_from_docs(doc) do
    doc
    |> String.split("\n\n")
    |> Enum.at(0)
  end

  defp format_type({:opaque, type}) do
    {:::, _, [ast, _]} = Typespec.type_to_ast(type)
    "@opaque #{format_spec_ast(ast)}"
  end

  defp format_type({kind, type}) do
    ast = Typespec.type_to_ast(type)
    "@#{kind} #{format_spec_ast(ast)}"
  end

  def format_spec_ast_single_line(spec_ast) do
    spec_ast
    |> Macro.prewalk(&drop_macro_env/1)
    |> spec_ast_to_string()
  end

  def format_spec_ast(spec_ast) do
    parts =
      spec_ast
      |> Macro.prewalk(&drop_macro_env/1)
      |> extract_spec_ast_parts

    name_str = Macro.to_string(parts.name)

    when_str =
      case parts[:when_part] do
        nil -> ""
        ast ->
          {:when, [], [:fake_lhs, ast]}
          |> Macro.to_string
          |> String.replace_prefix(":fake_lhs", "")
      end

    returns_str =
      parts.returns
      |> Enum.map(&Macro.to_string(&1))
      |> Enum.join(" |\n  ")

    formated_spec =
      case length(parts.returns) do
        1 -> "#{name_str} :: #{returns_str}#{when_str}\n"
        _ -> "#{name_str} ::\n  #{returns_str}#{when_str}\n"
      end

    formated_spec |> String.replace("()", "")
  end

  def define_callback?(mod, fun, arity) do
    mod
    |> Kernel.Typespec.beam_callbacks()
    |> Enum.any?(fn {{f, a}, _} -> {f, a} == {fun, arity}  end)
  end

  def get_returns_from_callback(module, func, arity) do
    parts =
      @wrapped_behaviours
      |> Map.get(module, module)
      |> get_callback_ast(func, arity)
      |> Macro.prewalk(&drop_macro_env/1)
      |> extract_spec_ast_parts

    for return <- parts.returns do
      ast = return |> strip_return_types()
      return =
        case parts[:when_part] do
          nil -> return
          _   -> {:when, [], [return, parts.when_part]}
        end

      spec     = return |> spec_ast_to_string()
      stripped = ast |> spec_ast_to_string()
      snippet  = ast |> return_to_snippet()
      %{description: stripped, spec: spec, snippet: snippet}
    end
  end

  defp extract_spec_ast_parts({:when, _, [{:::, _, [name_part, return_part]}, when_part]}) do
    %{name: name_part, returns: extract_return_part(return_part, []), when_part: when_part}
  end

  defp extract_spec_ast_parts({:::, _, [name_part, return_part]}) do
    %{name: name_part, returns: extract_return_part(return_part, [])}
  end

  defp extract_return_part({:|, _, [lhs, rhs]}, returns) do
    [lhs|extract_return_part(rhs, returns)]
  end

  defp extract_return_part(ast, returns) do
    [ast|returns]
  end

  defp get_type_doc(module, type) do
    case Code.get_docs(module, :type_docs) do
      nil  -> ""
      docs ->
        {{_, _}, _, _, description} = Enum.find(docs, fn({{name, _}, _, _, _}) ->
          type == name
        end)
        description || ""
    end
  end

  defp get_callback_with_doc(name, kind, doc, key, callbacks) do
    {_, [spec | _]} = List.keyfind(callbacks, key, 0)
    {_f, arity} = key

    spec_ast = name
    |> Typespec.spec_to_ast(spec)
    |> Macro.prewalk(&drop_macro_env/1)
    signature = get_typespec_signature(spec_ast, arity)
    definition = format_spec_ast(spec_ast)

    %{name: name, arity: arity, callback: "@#{kind} #{definition}", signature: signature, doc: doc}
  end

  defp get_callbacks_and_docs(mod) do
    callbacks = Typespec.beam_callbacks(mod)
    docs =
      @wrapped_behaviours
      |> Map.get(mod, mod)
      |> Code.get_docs(:callback_docs)

    {callbacks || [], docs || []}
  end

  defp drop_macro_env({name, meta, [{:::, _, [{:env, _, _}, _ | _]} | args]}), do: {name, meta, args}
  defp drop_macro_env(other), do: other

  defp get_typespec_signature({:when, _, [{:::, _, [{name, meta, args}, _]}, _]}, arity) do
    Macro.to_string {name, meta, strip_types(args, arity)}
  end

  defp get_typespec_signature({:::, _, [{name, meta, args}, _]}, arity) do
    Macro.to_string {name, meta, strip_types(args, arity)}
  end

  defp get_typespec_signature({name, meta, args}, arity) do
    Macro.to_string {name, meta, strip_types(args, arity)}
  end

  defp strip_types(args, arity) do
    args
    |> Enum.take(-arity)
    |> Enum.with_index()
    |> Enum.map(fn
      {{:::, _, [left, _]}, i} -> to_var(left, i)
      {{:|, _, _}, i}          -> to_var({}, i)
      {left, i}                -> to_var(left, i)
    end)
  end

  defp strip_return_types(returns) when is_list(returns) do
    returns |> Enum.map(&strip_return_types/1)
  end
  defp strip_return_types({:::, _, [left, _]}) do
    left
  end
  defp strip_return_types({:|, meta, args}) do
    {:|, meta, strip_return_types(args)}
  end
  defp strip_return_types({:{}, meta, args}) do
    {:{}, meta, strip_return_types(args)}
  end
  defp strip_return_types(value) do
    value
  end

  defp return_to_snippet(ast) do
    {ast, _} = Macro.prewalk(ast, 1, &term_to_snippet/2)
    ast |> Macro.to_string
  end
  defp term_to_snippet({name, _, nil} = ast, index) when is_atom(name) do
    next_snippet(ast, index)
  end
  defp term_to_snippet({:__aliases__, _, _} = ast, index) do
    next_snippet(ast, index)
  end
  defp term_to_snippet({{:., _, _}, _, _} = ast, index) do
    next_snippet(ast, index)
  end
  defp term_to_snippet({:|, _, _} = ast, index) do
    next_snippet(ast, index)
  end
  defp term_to_snippet(ast, index) do
    {ast, index}
  end
  defp next_snippet(ast, index) do
    {"${#{index}:#{spec_ast_to_string(ast)}}$", index + 1}
  end

  def param_to_var({{:=, _, [_lhs, {name, _, _} = rhs]}, arg_index}) when is_atom(name) do
    rhs
    |> to_var(arg_index + 1)
    |> Macro.to_string
  end

  def param_to_var({{:=, _, [{name, _, _} = lhs, _rhs]}, arg_index}) when is_atom(name) do
    lhs
    |> to_var(arg_index + 1)
    |> Macro.to_string
  end

  def param_to_var({{:\\, _, _} = ast, _}) do
    ast
    |> Macro.to_string
  end

  def param_to_var({ast, arg_index}) do
    ast
    |> to_var(arg_index + 1)
    |> Macro.to_string
  end

  defp to_var({:{}, _, _}, _),
    do: {:tuple, [], nil}
  defp to_var({_, _}, _),
    do: {:tuple, [], nil}
  defp to_var({name, meta, _}, _) when is_atom(name),
    do: {name, meta, nil}
  defp to_var({:<<>>, _, _}, _),
    do: {:binary, [], nil}
  defp to_var({:%{}, _, _}, _),
    do: {:map, [], nil}
  defp to_var(integer, _) when is_integer(integer),
    do: {:integer, [], nil}
  defp to_var(float, _) when is_float(float),
    do: {:float, [], nil}
  defp to_var(list, _) when is_list(list),
    do: {:list, [], nil}
  defp to_var(atom, _) when is_atom(atom),
    do: {:atom, [], nil}
  defp to_var(_, i),
    do: {:"arg#{i}", [], nil}

  def get_module_docs_summary(module) do
    case Code.get_docs module, :moduledoc do
      {_, doc} -> extract_summary_from_docs(doc)
      _ -> ""
    end
  end

  def get_module_subtype(module) do
    has_func = fn f, a -> Code.ensure_loaded?(module) && Kernel.function_exported?(module, f, a) end
    cond do
      has_func.(:__protocol__, 1) -> :protocol
      has_func.(:__impl__,     1) -> :implementation
      has_func.(:__struct__,   0) ->
        if Map.get(module.__struct__, :__exception__) do
          :exception
        else
          :struct
        end
      true -> nil
    end
  end

  def extract_fun_args_and_desc({{_fun, _}, _line, _kind, args, doc}) do
    formatted_args =
      args
      |> Enum.map_join(",", &format_doc_arg(&1))
      |> String.replace(Regex.recompile!(~r/\s+/), " ")
    desc = extract_summary_from_docs(doc)
    {formatted_args, desc}
  end

  def extract_fun_args_and_desc(nil) do
    {"", ""}
  end

  def get_module_specs(module) do
    case beam_specs(module) do
      nil   -> %{}
      specs ->
        for {_kind, {{f, a}, _spec}} = spec <- specs, into: %{} do
          {{f, a}, spec_to_string(spec)}
        end
    end
  end

  def get_spec(module, function, arity) when is_atom(module) and is_atom(function) and is_integer(arity) do
    module
    |> get_module_specs
    |> Map.get({function, arity}, "")
  end

  def get_spec_text(mod, fun, arity) do
    case get_spec(mod, fun, arity) do
      ""  -> ""
      spec ->
        "### Specs\n\n`#{spec}`\n\n"
    end
  end

  def module_to_string(module) do
    case module |> Atom.to_string do
      "Elixir." <> name -> name
      name -> ":#{name}"
    end
  end

  def split_mod_fun_call(call) do
    case Code.string_to_quoted(call) do
      {:error, _} ->
        {nil, nil}
      {:ok, quoted} when is_atom(quoted) ->
        {quoted, nil}
      {:ok, quoted} ->
        split_mod_quoted_fun_call(quoted)
    end
  end

  def split_mod_quoted_fun_call(quoted) do
    case Macro.decompose_call(quoted) do
      {{:__aliases__, _, mod_parts}, fun, _args} ->
        {Module.concat(mod_parts), fun}
      {:__aliases__, mod_parts} ->
        {Module.concat(mod_parts), nil}
      {mod, func, []} when is_atom(mod) and is_atom(func) ->
        {mod, func}
      {func, []} when is_atom(func) ->
        {nil, func}
      _ -> {nil, nil}
    end
  end

  def module_functions_info(module) do
    docs = Code.get_docs(module, :docs) || []
    specs = get_module_specs(module)
    for {{f, a}, _line, func_kind, _sign, doc} = func_doc <- docs, doc != false, into: %{} do
      spec = Map.get(specs, {f, a}, "")
      {fun_args, desc} = extract_fun_args_and_desc(func_doc)
      {{f, a}, {func_kind, fun_args, desc, spec}}
    end
  end

  def get_callback_ast(module, callback, arity) do
    {{name, _}, [spec | _]} = module
      |> Kernel.Typespec.beam_callbacks()
      |> Enum.find(fn {{f, a}, _} -> {f, a} == {callback, arity}  end)

    Kernel.Typespec.spec_to_ast(name, spec)
  end

  defp format_doc_arg({:\\, _, [left, right]}) do
    format_doc_arg(left) <> " \\\\ " <> Macro.to_string(right)
  end

  defp format_doc_arg({var, _, _}) do
    Atom.to_string(var)
  end

  defp spec_ast_to_string(ast) do
    ast |> Macro.to_string |> String.replace("()", "")
  end

  defp spec_to_string({kind, {{name, _arity}, specs}}) do
    spec = hd(specs)
    binary = Macro.to_string Typespec.spec_to_ast(name, spec)
    "@#{kind} #{binary}" |> String.replace("()", "")
  end

  defp beam_specs(module) do
    beam_specs_tag(Typespec.beam_specs(module), :spec)
  end

  defp beam_specs_tag(nil, _), do: nil
  defp beam_specs_tag(specs, tag) do
    Enum.map(specs, &{tag, &1})
  end

  def actual_mod_fun(mod_fun, imports, aliases, current_module) do
    with {nil, nil} <- find_kernel_function(mod_fun),
         {nil, nil} <- find_imported_function(mod_fun, imports),
         {nil, nil} <- find_aliased_function(mod_fun, aliases),
         {nil, nil} <- find_function_in_module(mod_fun),
         {nil, nil} <- find_function_in_current_module(mod_fun, current_module)
    do
      mod_fun
    else
      new_mod_fun -> new_mod_fun
    end
  end

  defp find_kernel_function({nil, fun}) do
    cond do
      ModuleInfo.docs?(Kernel, fun) ->
        {Kernel, fun}
      ModuleInfo.docs?(Kernel.SpecialForms, fun) ->
        {Kernel.SpecialForms, fun}
      true -> {nil, nil}
    end
  end

  defp find_kernel_function({_mod, _fun}) do
    {nil, nil}
  end

  defp find_imported_function({nil, fun}, imports) do
    case imports |> Enum.find(&ModuleInfo.has_function?(&1, fun)) do
      nil -> {nil, nil}
      mod  -> {mod, fun}
    end
  end

  defp find_imported_function({_mod, _fun}, _imports) do
    {nil, nil}
  end

  defp find_aliased_function({nil, _fun}, _aliases) do
    {nil, nil}
  end

  defp find_aliased_function({mod, fun}, aliases) do
    if elixir_module?(mod) do
      module =
        mod
        |> Module.split
        |> ModuleInfo.expand_alias(aliases)
      {module, fun}
    else
      {nil, nil}
    end
  end

  defp find_function_in_module({mod, fun}) do
    if elixir_module?(mod) && ModuleInfo.has_function?(mod, fun) do
      {mod, fun}
    else
      {nil, nil}
    end
  end

  defp find_function_in_current_module({nil, fun}, current_module) do
    {current_module, fun}
  end

  defp find_function_in_current_module(_, _) do
    {nil, nil}
  end

  defp elixir_module?(module) when is_atom(module) do
    module == Module.concat(Elixir, module)
  end
  defp elixir_module?(_) do
    false
  end

end
