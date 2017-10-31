defmodule ElixirSense.Core.Ast do
  @moduledoc """
  Abstract Syntax Tree support
  """

  alias ElixirSense.Core.Introspection

  @empty_env_info %{requires: [], imports: [], behaviours: []}

  @partials [:def, :defp, :defmodule, :@, :defmacro, :defmacrop, :defoverridable,
  :__ENV__, :__CALLER__, :raise, :if, :unless, :in]

  @max_expand_count 30_000

  def extract_use_info(use_ast, module, state) do

    %{aliases: aliases} = state
    current_aliases = aliases |> :lists.reverse |> List.flatten
    env = Map.merge(__ENV__, %{module: module, function: nil, aliases: current_aliases})

    {expanded_ast, _requires} = Macro.prewalk(use_ast, {env, 1}, &do_expand/2)
    {_ast, env_info} = Macro.prewalk(expanded_ast, @empty_env_info, &pre_walk_expanded/2)
    env_info
  catch
    {:expand_error, _} ->
      IO.puts(:stderr, "Info: ignoring recursive macro")
      @empty_env_info
  end

  def expand_partial(ast, env) do
    {expanded_ast, _} = Macro.prewalk(ast, {env, 1}, &do_expand_partial/2)
    expanded_ast
  rescue
    _e -> ast
  catch
    e -> e
  end

  def expand_all(ast, env) do
    try do
      {expanded_ast, _} = Macro.prewalk(ast, {env, 1}, &do_expand_all/2)
      expanded_ast
    rescue
      _e -> ast
    catch
      e -> e
    end
  end

  def set_module_for_env(env, module) do
    Map.put(env, :module, module)
  end

  def add_requires_to_env(env, modules) do
    add_directive_modules_to_env(env, :require, modules)
  end

  def add_imports_to_env(env, modules) do
    add_directive_modules_to_env(env, :import, modules)
  end

  defp add_directive_modules_to_env(env, directive, modules) do
    directive_string = modules
    |> Enum.map(&"#{directive} #{Introspection.module_to_string(&1)}")
    |> Enum.join("; ")
    {new_env, _} = Code.eval_string("#{directive_string}; __ENV__", [], env)
    new_env
  end

  defp do_expand_all(ast, acc) do
    do_expand(ast, acc)
  end

  defp do_expand_partial({name, _, _} = ast, acc) when name in @partials do
    {ast, acc}
  end
  defp do_expand_partial(ast, acc) do
    do_expand(ast, acc)
  end

  defp do_expand({:require, _, _} = ast, {env, count}) do
    modules = extract_directive_modules(:require, ast)
    new_env = add_requires_to_env(env, modules)
    {ast, {new_env, count}}
  end

  defp do_expand(ast, acc) do
    do_expand_with_fixes(ast, acc)
  end

  # Fix inexpansible `use ExUnit.Case`
  defp do_expand_with_fixes({:use, _, [{:__aliases__, _, [:ExUnit, :Case]}|_]}, acc) do
    ast = quote do
      import ExUnit.Callbacks
      import ExUnit.Assertions
      import ExUnit.Case
      import ExUnit.DocTest
    end
    {ast, acc}
  end

  defp do_expand_with_fixes(ast, {env, count}) do
    if count > @max_expand_count do
      throw {:expand_error, "Cannot expand recursive macro"}
    end
    try do
      expanded_ast = Macro.expand(ast, env)
      {expanded_ast, {env, count + 1}}
    rescue
      _e ->
        {ast, {env, count + 1}}
    end
  end

  defp pre_walk_expanded({:__block__, _, _} = ast, acc) do
    {ast, acc}
  end
  defp pre_walk_expanded({:require, _, _} = ast, acc) do
    modules = extract_directive_modules(:require, ast)
    {ast, %{acc | requires: (acc.requires ++ modules)}}
  end
  defp pre_walk_expanded({:import, _, _} = ast, acc) do
    modules = extract_directive_modules(:import, ast)
    {ast, %{acc | imports: (acc.imports ++ modules)}}
  end
  defp pre_walk_expanded({:@, _, [{:behaviour, _, [behaviour]}]} = ast, acc) do
    {ast, %{acc | behaviours: [behaviour|acc.behaviours]}}
  end
  defp pre_walk_expanded({{:., _, [Module, :put_attribute]}, _, [_module, :behaviour, behaviour | _]} = ast, acc) do
    {ast, %{acc | behaviours: [behaviour|acc.behaviours]}}
  end
  defp pre_walk_expanded({_name, _meta, _args}, acc) do
    {nil, acc}
  end
  defp pre_walk_expanded(ast, acc) do
    {ast, acc}
  end

  defp extract_directive_modules(directive, ast) do
    case ast do
      # v1.2 notation
      {^directive, _, [{{:., _, [{:__aliases__, _, prefix_atoms}, :{}]}, _, aliases}]} ->
        aliases |> Enum.map(fn {:__aliases__, _, mods} ->
          Module.concat(prefix_atoms ++ mods)
        end)
      # with options
      {^directive, _, [{_, _, module_atoms = [mod|_]}, _opts]} when is_atom(mod) ->
        [module_atoms |> Module.concat]
      # with options
      {^directive, _, [module, _opts]} when is_atom(module) ->
        [module]
      # with options
      {^directive, _, [{:__aliases__, _, module_parts}, _opts]} ->
        [module_parts |> Module.concat]
      # without options
      {^directive, _, [{:__aliases__, _, module_parts}]} ->
        [module_parts |> Module.concat]
      # without options
      {^directive, _, [{:__aliases__, [alias: false, counter: _], module_parts}]} ->
        [module_parts |> Module.concat]
      # without options
      {^directive, _, [module]} ->
        [module]
    end
  end
end
