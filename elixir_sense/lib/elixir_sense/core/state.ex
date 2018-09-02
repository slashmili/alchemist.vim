defmodule ElixirSense.Core.State do
  @moduledoc """
  Core State
  """

  defstruct [
    namespace:  [:Elixir],
    scopes:     [:Elixir],
    imports:    [[]],
    requires:   [[]],
    aliases:    [[]],
    attributes: [[]],
    scope_attributes: [[]],
    behaviours: [[]],
    scope_behaviours: [[]],
    vars:       [[]],
    scope_vars: [[]],
    scope_id_count: 0,
    scope_ids:  [0],
    vars_info_per_scope_id: %{},
    mods_funs_to_positions: %{},
    lines_to_env: %{}
  ]

  defmodule Env do
    @moduledoc false
    defstruct [
      imports: [],
      requires: [],
      aliases: [],
      module: nil,
      vars: [],
      attributes: [],
      behaviours: [],
      scope: nil,
      scope_id: nil,
    ]
  end

  defmodule VarInfo do
    @moduledoc false
    defstruct name: nil, positions: [], scope_id: nil, is_definition: nil
  end

  def get_current_env(state) do
    current_module     = get_current_module(state)
    current_imports    = state.imports    |> :lists.reverse |> List.flatten
    current_requires   = state.requires   |> :lists.reverse |> List.flatten
    current_aliases    = state.aliases    |> :lists.reverse |> List.flatten
    current_vars       = state |> get_current_vars()
    current_attributes = state.scope_attributes |> :lists.reverse |> List.flatten
    current_behaviours = hd(state.behaviours)
    current_scope      = hd(state.scopes)
    current_scope_id   = hd(state.scope_ids)

    %Env{
      imports: current_imports,
      requires: current_requires,
      aliases: current_aliases,
      module: current_module,
      vars: current_vars,
      attributes: current_attributes,
      behaviours: current_behaviours,
      scope: current_scope,
      scope_id: current_scope_id,
    }
  end

  def get_current_module(state) do
    state.namespace |> :lists.reverse |> Module.concat
  end

  def add_current_env_to_line(state, line) do
    env = get_current_env(state)
    %{state | lines_to_env: Map.put(state.lines_to_env, line, env)}
  end

  def get_scope_name(state, line) do
    case state.lines_to_env[line] do
      nil -> nil
      %Env{scope: scope} -> scope
    end
  end

  def get_current_scope_name(state) do
    scope = case hd(state.scopes) do
      {fun, _} -> fun
      mod      -> mod
    end
    scope |> Atom.to_string()
  end

  def get_current_vars(state) do
    state.scope_vars |> List.flatten |> reduce_vars() |> Map.values()
  end

  def get_current_vars_refs(state) do
    state.scope_vars |> List.flatten
  end

  def is_variable_defined(state, var_name) do
    state
    |> get_current_vars_refs()
    |> Enum.any?(fn %VarInfo{name: name, is_definition: is_definition} -> name == var_name && is_definition end)
  end

  def add_mod_fun_to_position(state, {module, fun, arity}, position, params) do
    current_info = Map.get(state.mods_funs_to_positions, {module, fun, arity}, %{})
    current_params = current_info |> Map.get(:params, [])
    current_positions = current_info |> Map.get(:positions, [])
    new_params = [params|current_params]
    new_positions = [position|current_positions]

    mods_funs_to_positions = Map.put(state.mods_funs_to_positions, {module, fun, arity}, %{positions: new_positions, params: new_params})
    %{state | mods_funs_to_positions: mods_funs_to_positions}
  end

  def new_namespace(state, module) do
    module_reversed = :lists.reverse(module)
    namespace = module_reversed ++ state.namespace
    scopes  = module_reversed ++ state.scopes
    %{state | namespace: namespace, scopes: scopes}
  end

  def remove_module_from_namespace(state, module) do
    outer_mods = Enum.drop(state.namespace, length(module))
    outer_scopes = Enum.drop(state.scopes, length(module))
    %{state | namespace: outer_mods, scopes: outer_scopes}
  end

  def new_named_func(state, name, arity) do
    %{state | scopes: [{name, arity}|state.scopes]}
  end

  def remove_last_scope_from_scopes(state) do
    %{state | scopes: tl(state.scopes)}
  end

  def add_current_module_to_index(state, position) do
    current_module = state.namespace |> :lists.reverse |> Module.concat
    add_mod_fun_to_position(state, {current_module, nil, nil}, position, nil)
  end

  def add_func_to_index(state, func, params, position) do
    current_module = state.namespace |> :lists.reverse |> Module.concat
    state
    |> add_mod_fun_to_position({current_module, func, length(params)}, position, params)
    |> add_mod_fun_to_position({current_module, func, nil}, position, params)
  end

  def new_alias_scope(state) do
    %{state | aliases: [[]|state.aliases]}
  end

  def create_alias_for_current_module(state) do
    if length(state.namespace) > 2 do
      current_module = state.namespace |> :lists.reverse |> Module.concat
      alias_tuple = {Module.concat([hd(state.namespace)]), current_module}
      state |> add_alias(alias_tuple)
    else
      state
    end
  end

  def remove_alias_scope(state) do
    %{state | aliases: tl(state.aliases)}
  end

  def new_vars_scope(state) do
    scope_id = state.scope_id_count + 1
    %{state | scope_ids: [scope_id | state.scope_ids], scope_id_count: scope_id, vars: [[]|state.vars], scope_vars: [[]|state.scope_vars]}
  end

  def new_func_vars_scope(state) do
    %{state | vars: [[]|state.vars], scope_vars: [[]]}
  end

  def new_attributes_scope(state) do
    %{state | attributes: [[]|state.attributes], scope_attributes: [[]]}
  end

  def new_behaviours_scope(state) do
    %{state | behaviours: [[]|state.behaviours], scope_behaviours: [[]]}
  end

  def remove_vars_scope(state) do
    [current_scope_vars | other_scope_vars] = state.scope_vars
    [scope_id | other_scope_ids] = state.scope_ids
    vars_info_per_scope_id = state.vars_info_per_scope_id |> Map.put(scope_id, reduce_vars(current_scope_vars))
    %{state | scope_ids: other_scope_ids, vars: tl(state.vars), scope_vars: other_scope_vars, vars_info_per_scope_id: vars_info_per_scope_id}
  end

  def remove_func_vars_scope(state) do
    vars = tl(state.vars)
    %{state | vars: vars, scope_vars: vars}
  end

  def remove_attributes_scope(state) do
    attributes = tl(state.attributes)
    %{state | attributes: attributes, scope_attributes: attributes}
  end

  def remove_behaviours_scope(state) do
    behaviours = tl(state.behaviours)
    %{state | behaviours: behaviours, scope_behaviours: behaviours}
  end

  def add_alias(state, alias_tuple) do
    [aliases_from_scope|inherited_aliases] = state.aliases
    %{state | aliases: [[alias_tuple|aliases_from_scope]|inherited_aliases]}
  end

  def add_aliases(state, aliases_tuples) do
    Enum.reduce(aliases_tuples, state, fn(tuple, state) -> add_alias(state, tuple) end)
  end

  def new_import_scope(state) do
    %{state | imports: [[]|state.imports]}
  end

  def new_require_scope(state) do
    %{state | requires: [[]|state.requires]}
  end

  def remove_import_scope(state) do
    %{state | imports: tl(state.imports)}
  end

  def remove_require_scope(state) do
    %{state | requires: tl(state.requires)}
  end

  def add_import(state, module) do
    [imports_from_scope|inherited_imports] = state.imports
    %{state | imports: [[module|imports_from_scope]|inherited_imports]}
  end

  def add_imports(state, modules) do
    Enum.reduce(modules, state, fn(mod, state) -> add_import(state, mod) end)
  end

  def add_require(state, module) do
    [requires_from_scope|inherited_requires] = state.requires
    %{state | requires: [[module|requires_from_scope]|inherited_requires]}
  end

  def add_requires(state, modules) do
    Enum.reduce(modules, state, fn(mod, state) -> add_require(state, mod) end)
  end

  def add_var(state, %{name: var_name} = var_info, is_definition) do
    scope = get_current_scope_name(state)
    [vars_from_scope|other_vars] = state.vars
    is_var_defined = is_variable_defined(state, var_name)
    var_name_as_string = Atom.to_string(var_name)

    vars_from_scope =
      case {is_definition, is_var_defined, var_name_as_string} do
        {_, _, "_" <> _}  -> vars_from_scope
        {_, _, ^scope}    -> vars_from_scope
        {true, _, _ }     -> [%VarInfo{var_info | scope_id: hd(state.scope_ids), is_definition: is_definition} | vars_from_scope]
        {false, true, _ } -> [%VarInfo{var_info | scope_id: hd(state.scope_ids), is_definition: is_definition} | vars_from_scope]
        _                 -> vars_from_scope
      end

    %{state | vars: [vars_from_scope|other_vars], scope_vars: [vars_from_scope|tl(state.scope_vars)]}
  end

  def add_attribute(state, attribute) do
    [attributes_from_scope|other_attributes] = state.attributes

    attributes_from_scope =
      if attribute in attributes_from_scope do
        attributes_from_scope
      else
        [attribute|attributes_from_scope]
      end
    attributes = [attributes_from_scope|other_attributes]
    scope_attributes = [attributes_from_scope|tl(state.scope_attributes)]
    %{state | attributes: attributes, scope_attributes: scope_attributes}
  end

  def add_behaviour(state, module) do
    [behaviours_from_scope|other_behaviours] = state.behaviours
    %{state | behaviours: [[module|behaviours_from_scope]|other_behaviours]}
  end

  def add_behaviours(state, modules) do
    Enum.reduce(modules, state, fn(mod, state) -> add_behaviour(state, mod) end)
  end

  def add_vars(state, vars, is_definition) do
    vars |> Enum.reduce(state, fn(var, state) -> add_var(state, var, is_definition) end)
  end

  defp reduce_vars(vars) do
    Enum.reduce(vars, %{}, fn %VarInfo{name: var, positions: positions, scope_id: scope_id}, acc ->
      var_info = Map.get(acc, var, %VarInfo{name: var, positions: [], scope_id: scope_id})
      var_info = %VarInfo{var_info | positions: Enum.sort(var_info.positions ++ positions)}
      Map.put(acc, var, var_info)
    end)
  end
end
