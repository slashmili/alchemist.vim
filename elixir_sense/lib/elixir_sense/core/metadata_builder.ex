defmodule ElixirSense.Core.MetadataBuilder do

  @moduledoc """
  This module is responsible for building/retrieving environment information from an AST.
  """

  import ElixirSense.Core.State
  alias ElixirSense.Core.Ast
  alias ElixirSense.Core.State

  @scope_keywords [:for, :try, :fn]
  @block_keywords [:do, :else, :rescue, :catch, :after]
  @defs [:def, :defp, :defmacro, :defmacrop]

  @doc """
  Traverses the AST building/retrieving the environment information.
  It returns a `ElixirSense.Core.State` struct containing the information.
  """
  def build(ast) do
    {_ast, state} = Macro.traverse(ast, %State{}, &pre/2, &post/2)
    state
  end

  defp pre_module(ast, state, line, module) do
    state
    |> new_namespace(module)
    |> add_current_module_to_index(line)
    |> create_alias_for_current_module
    |> new_attributes_scope
    |> new_behaviours_scope
    |> new_alias_scope
    |> new_import_scope
    |> new_require_scope
    |> new_vars_scope
    |> result(ast)
  end

  defp post_module(ast, state, module) do
    state
    |> remove_module_from_namespace(module)
    |> remove_attributes_scope
    |> remove_behaviours_scope
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_require_scope
    |> remove_vars_scope
    |> result(ast)
  end

  defp pre_func(ast, state, line, name, params) do
    state
    |> new_named_func(name, length(params || []))
    |> add_current_env_to_line(line)
    |> add_func_to_index(name, params || [], line)
    |> new_alias_scope
    |> new_import_scope
    |> new_require_scope
    |> new_func_vars_scope
    |> add_vars(find_vars(params))
    |> result(ast)
  end

  defp post_func(ast, state) do
    state
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_require_scope
    |> remove_func_vars_scope
    |> remove_last_scope_from_scopes
    |> result(ast)
  end

  defp pre_scope_keyword(ast, state, line) do
    state
    |> add_current_env_to_line(line)
    |> new_vars_scope
    |> result(ast)
  end

  defp post_scope_keyword(ast, state) do
    state
    |> remove_vars_scope
    |> result(ast)
  end

  defp pre_block_keyword(ast, state) do
    state
    |> new_alias_scope
    |> new_import_scope
    |> new_require_scope
    |> new_vars_scope
    |> result(ast)
  end

  defp post_block_keyword(ast, state) do
    state
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_require_scope
    |> remove_vars_scope
    |> result(ast)
  end

  defp pre_clause(ast, state, lhs) do
    state
    |> new_alias_scope
    |> new_import_scope
    |> new_require_scope
    |> new_vars_scope
    |> add_vars(find_vars(lhs))
    |> result(ast)
  end

  defp post_clause(ast, state) do
    state
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_require_scope
    |> remove_vars_scope
    |> result(ast)
  end

  defp pre_alias(ast, state, line, aliases_tuples) when is_list(aliases_tuples) do
    state
    |> add_current_env_to_line(line)
    |> add_aliases(aliases_tuples)
    |> result(ast)
  end

  defp pre_alias(ast, state, line, alias_tuple) do
    state
    |> add_current_env_to_line(line)
    |> add_alias(alias_tuple)
    |> result(ast)
  end

  defp pre_import(ast, state, line, modules) when is_list(modules) do
    state
    |> add_current_env_to_line(line)
    |> add_imports(modules)
    |> result(ast)
  end

  defp pre_import(ast, state, line, module) do
    state
    |> add_current_env_to_line(line)
    |> add_import(module)
    |> result(ast)
  end

  defp pre_require(ast, state, line, modules) when is_list(modules) do
    state
    |> add_current_env_to_line(line)
    |> add_requires(modules)
    |> result(ast)
  end

  defp pre_require(ast, state, line, module) do
    state
    |> add_current_env_to_line(line)
    |> add_require(module)
    |> result(ast)
  end

  defp pre_module_attribute(ast, state, line, name) do
    state
    |> add_current_env_to_line(line)
    |> add_attribute(name)
    |> result(ast)
  end

  defp pre_behaviour(ast, state, line, module) do
    state
    |> add_current_env_to_line(line)
    |> add_behaviour(module)
    |> result(ast)
  end

  defp pre({:defmodule, [line: line], [{:__aliases__, _, module}, _]} = ast, state) do
    pre_module(ast, state, line, module)
  end

  defp pre({def_name, meta, [{:when, _, [head|_]}, body]}, state) when def_name in @defs do
    pre({def_name, meta, [head, body]}, state)
  end

  defp pre({def_name, [line: line], [{name, _, params}, _body]} = ast, state) when def_name in @defs and is_atom(name) do
    pre_func(ast, state, line, name, params)
  end

  defp pre({def_name, _, _} = ast, state) when def_name in @defs do
    {ast, state}
  end

  defp pre({:@, [line: line], [{:behaviour, _, [{:__aliases__, _, module_atoms}]}]} = ast, state) do
    module = module_atoms |> Module.concat
    pre_behaviour(ast, state, line, module)
  end

  defp pre({:@, [line: line], [{:behaviour, _, [erlang_module]}]} = ast, state) do
    pre_behaviour(ast, state, line, erlang_module)
  end

  defp pre({:@, [line: line], [{name, _, _}]} = ast, state) do
    pre_module_attribute(ast, state, line, name)
  end

  # import with v1.2 notation
  defp pre({:import, [line: line], [{{:., _, [{:__aliases__, _, prefix_atoms}, :{}]}, _, imports}]} = ast, state) do
    imports_modules = imports |> Enum.map(fn {:__aliases__, _, mods} ->
      Module.concat(prefix_atoms ++ mods)
    end)
    pre_import(ast, state, line, imports_modules)
  end

  # import without options
  defp pre({:import, meta, [module_info]}, state) do
    pre({:import, meta, [module_info, []]}, state)
  end

  # import with options
  defp pre({:import, [line: line], [{_, _, module_atoms = [mod|_]}, _opts]} = ast, state) when is_atom(mod) do
    module = module_atoms |> Module.concat
    pre_import(ast, state, line, module)
  end

  # require with v1.2 notation
  defp pre({:require, [line: line], [{{:., _, [{:__aliases__, _, prefix_atoms}, :{}]}, _, requires}]} = ast, state) do
    requires_modules = requires |> Enum.map(fn {:__aliases__, _, mods} ->
      Module.concat(prefix_atoms ++ mods)
    end)
    pre_require(ast, state, line, requires_modules)
  end

  # require without options
  defp pre({:require, meta, [module_info]}, state) do
    pre({:require, meta, [module_info, []]}, state)
  end

  # require with options
  defp pre({:require, [line: line], [{_, _, module_atoms = [mod|_]}, _opts]} = ast, state) when is_atom(mod) do
    module = module_atoms |> Module.concat
    pre_require(ast, state, line, module)
  end

  # alias with v1.2 notation
  defp pre({:alias, [line: line], [{{:., _, [{:__aliases__, _, prefix_atoms}, :{}]}, _, aliases}]} = ast, state) do
    aliases_tuples = aliases |> Enum.map(fn {:__aliases__, _, mods} ->
      {Module.concat(mods), Module.concat(prefix_atoms ++ mods)}
    end)
    pre_alias(ast, state, line, aliases_tuples)
  end

  # alias without options
  defp pre({:alias, [line: line], [{:__aliases__, _, module_atoms = [mod|_]}]} = ast, state) when is_atom(mod) do
    alias_tuple = {Module.concat([List.last(module_atoms)]), Module.concat(module_atoms)}
    pre_alias(ast, state, line, alias_tuple)
  end

  # alias with `as` option
  defp pre({:alias, [line: line], [{_, _, module_atoms = [mod|_]}, [as: {:__aliases__, _, alias_atoms = [al|_]}]]} = ast, state) when is_atom(mod) and is_atom(al) do
    alias_tuple = {Module.concat(alias_atoms), Module.concat(module_atoms)}
    pre_alias(ast, state, line, alias_tuple)
  end

  defp pre({atom, [line: line], _} = ast, state) when atom in @scope_keywords do
    pre_scope_keyword(ast, state, line)
  end

  defp pre({atom, _block} = ast, state) when atom in @block_keywords do
    pre_block_keyword(ast, state)
  end

  defp pre({:->, [line: _line], [lhs, _rhs]} = ast, state) do
    pre_clause(ast, state, lhs)
  end

  defp pre({:=, _meta, [lhs, _rhs]} = ast, state) do
    state
    |> add_vars(find_vars(lhs))
    |> result(ast)
  end

  defp pre({:<-, _meta, [lhs, _rhs]} = ast, state) do
    state
    |> add_vars(find_vars(lhs))
    |> result(ast)
  end

  # Kernel: defmacro use(module, opts \\ [])
  defp pre({:use, [line: _], [{param, _, nil}|_]} = ast, state) when is_atom(param) do
    state
    |> result(ast)
  end

  defp pre({:use, [line: line], _} = ast, state) do
    %{requires: requires, imports: imports, behaviours: behaviours} = Ast.extract_use_info(ast, get_current_module(state), state)

    state
    |> add_current_env_to_line(line)
    |> add_requires(requires)
    |> add_imports(imports)
    |> add_behaviours(behaviours)
    |> result(ast)
  end

  # Any other tuple with a line
  defp pre({_, [line: line], _} = ast, state) do
    state
    |> add_current_env_to_line(line)
    |> result(ast)
  end

  # No line defined
  defp pre(ast, state) do
    {ast, state}
  end

  defp post({:defmodule, _, [{:__aliases__, _, module}, _]} = ast, state) do
    post_module(ast, state, module)
  end

  defp post({def_name, [line: _line], [{name, _, _params}, _]} = ast, state) when def_name in @defs and is_atom(name) do
    post_func(ast, state)
  end

  defp post({def_name, _, _} = ast, state) when def_name in @defs do
    {ast, state}
  end

  defp post({atom, _, _} = ast, state) when atom in @scope_keywords do
    post_scope_keyword(ast, state)
  end

  defp post({atom, _block} = ast, state) when atom in @block_keywords do
    post_block_keyword(ast, state)
  end

  defp post({:->, [line: _line], [_lhs, _rhs]} = ast, state) do
    post_clause(ast, state)
  end

  defp post(ast, state) do
    {ast, state}
  end

  defp result(state, ast) do
    {ast, state}
  end

  defp find_vars(ast) do
    {_ast, vars} = Macro.prewalk(ast, [], &match_var/2)
    vars |> Enum.uniq_by(&(&1))
  end

  defp match_var({var, [line: _], context} = ast, vars) when is_atom(var) and context in [nil, Elixir] do
    {ast, [var|vars]}
  end

  defp match_var(ast, vars) do
    {ast, vars}
  end

end
