defmodule ElixirSense.Core.MetadataBuilderTest do

  use ExUnit.Case

  alias ElixirSense.Core.MetadataBuilder

  test "build metadata from kernel.ex" do
    assert get_subject_definition_line(Kernel, :defmodule, nil) =~ "defmacro defmodule(alias, do: block) do"
  end

  test "build metadata from kernel/special_forms.ex" do
    assert get_subject_definition_line(Kernel.SpecialForms, :alias, nil) =~ "defmacro alias(module, opts)"
  end

  test "module attributes" do
    state = """
      defmodule MyModule do
        @myattribute 1
        IO.puts @myattribute
        defmodule InnerModule do
          @inner_attr module_var
          IO.puts @inner_attr
        end
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_attributes(state, 3) == [:myattribute]
    assert get_line_attributes(state, 6) == [:inner_attr]
    assert get_line_attributes(state, 8) == [:myattribute]
  end

  test "vars defined inside a function without params" do
    state = """
      defmodule MyModule do
        var_out1 = 1
        def func do
          var_in1 = 1
          var_in2 = 1
          IO.puts ""
        end
        var_out2 = 1
      end
      """
      |> string_to_state

    vars = state |> get_line_vars(6)
    assert vars == [:var_in1, :var_in2]
  end

  test "vars defined inside a function with params" do

    state = """
      defmodule MyModule do
        var_out1 = 1
        def func(%{key1: par1, key2: [par2|[par3, _]]}, par4) do
          var_in1 = 1
          var_in2 = 1
          IO.puts ""
        end
        var_out2 = 1
      end
      """
      |> string_to_state

    vars = state |> get_line_vars(6)
    assert vars == [:par1, :par2, :par3, :par4, :var_in1, :var_in2]
  end

  test "vars defined inside a module" do

    state =
      """
      defmodule MyModule do
        var_out1 = 1
        def func do
          var_in = 1
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> string_to_state

    vars = state |> get_line_vars(7)
    assert vars == [:var_out1, :var_out2]
  end

  test "vars defined in a `for` comprehension" do

    state =
      """
      defmodule MyModule do
        var_out1 = 1
        IO.puts ""
        for var_on <- [1,2], var_on != 2 do
          var_in = 1
          IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 3) == [:var_out1]
    assert get_line_vars(state, 6) == [:var_in, :var_on, :var_out1]
    assert get_line_vars(state, 9) == [:var_out1, :var_out2]
  end

  test "vars defined in a `if/else` statement" do

    state =
      """
      defmodule MyModule do
        var_out1 = 1
        if var_on = true do
          var_in_if = 1
          IO.puts ""
        else
          var_in_else = 1
          IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 5) == [:var_in_if, :var_on, :var_out1]
    assert get_line_vars(state, 8) == [:var_in_else, :var_on, :var_out1]
    # This assert fails:
    # assert get_line_vars(state, 11) == [:var_in_else, :var_in_if, :var_on, :var_out1, :var_out2]
  end

  test "vars defined inside a `fn`" do

    state =
      """
      defmodule MyModule do
        var_out1 = 1
        fn var_on ->
          var_in = 1
          IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 5) == [:var_in, :var_on, :var_out1]
    assert get_line_vars(state, 8) == [:var_out1, :var_out2]
  end

  test "vars defined inside a `case`" do

    state =
      """
      defmodule MyModule do
        var_out1 = 1
        case var_out1 do
          {var_on1} ->
            var_in1 = 1
            IO.puts ""
          {var_on2} ->
            var_in2 = 2
            IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 6) == [:var_in1, :var_on1, :var_out1]
    assert get_line_vars(state, 9) == [:var_in2, :var_on2, :var_out1]
    # This assert fails
    # assert get_line_vars(state, 12) == [:var_in1, :var_in2, :var_out1, :var_out2]
  end

  test "vars defined inside a `cond`" do

    state =
      """
      defmodule MyModule do
        var_out1 = 1
        cond do
          1 == 1 ->
            var_in = 1
            IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 6) == [:var_in, :var_out1]
    # This assert fails:
    # assert get_line_vars(state, 9) == [:var_in, :var_out1, :var_out2]
  end

  test "a variable should only be added once to the vars list" do

    state =
      """
      defmodule MyModule do
        var = 1
        var = 2
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 4) == [:var]
  end

  test "functions of arity 0 should not be in the vars list" do

    state =
      """
      defmodule MyModule do
        myself = self
        mynode = node()
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_vars(state, 3) == [:mynode, :myself]
  end

  test "inherited vars" do

    state =
      """
      top_level_var = 1
      IO.puts ""
      defmodule OuterModule do
        outer_module_var = 1
        IO.puts ""
        defmodule InnerModule do
          inner_module_var = 1
          IO.puts ""
          def func do
            func_var = 1
            IO.puts ""
          end
          IO.puts ""
        end
        IO.puts ""
      end
      IO.puts ""
      """
      |> string_to_state

    assert get_line_vars(state, 2)  == [:top_level_var]
    assert get_line_vars(state, 5)  == [:outer_module_var, :top_level_var]
    assert get_line_vars(state, 8)  == [:inner_module_var, :outer_module_var, :top_level_var]
    assert get_line_vars(state, 11) == [:func_var]
    assert get_line_vars(state, 13) == [:inner_module_var, :outer_module_var, :top_level_var]
    assert get_line_vars(state, 15) == [:outer_module_var, :top_level_var]
    assert get_line_vars(state, 17) == [:top_level_var]
  end

  test "aliases" do

    state =
      """
      defmodule OuterModule do
        alias List, as: MyList
        IO.puts ""
        defmodule InnerModule do
          alias Enum, as: MyEnum
          IO.puts ""
          def func do
            alias String, as: MyString
            IO.puts ""
            if true do
              alias Macro, as: MyMacro
              IO.puts ""
            end
            IO.puts ""
          end
          IO.puts ""
        end
        alias Code, as: MyCode
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_aliases(state, 3)  == [{MyList, List}]
    assert get_line_aliases(state, 6)  == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}]
    assert get_line_aliases(state, 9)  == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}, {MyString, String}]
    assert get_line_aliases(state, 12) == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}, {MyString, String}, {MyMacro, Macro}]
    assert get_line_aliases(state, 14) == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}, {MyString, String}]
    assert get_line_aliases(state, 16) == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}]
    assert get_line_aliases(state, 19) == [{MyCode, Code}, {InnerModule, OuterModule.InnerModule}, {MyList, List}]
  end

  test "aliases with `fn`" do

    state =
      """
      defmodule MyModule do
        alias Enum, as: MyEnum
        IO.puts ""
        fn var_on ->
          alias List, as: MyList
          IO.puts ""
        end
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_aliases(state, 3) == [{MyEnum, Enum}]
    assert get_line_aliases(state, 6) == [{MyEnum, Enum}, {MyList, List}]
    assert get_line_aliases(state, 8) == [{MyEnum, Enum}]
  end

  test "aliases defined with v1.2 notation" do

    state =
      """
      defmodule MyModule do
        alias Foo.{User, Email}
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_aliases(state, 3) == [{Email, Foo.Email}, {User, Foo.User}]
  end

  test "aliases without options" do

    state =
      """
      defmodule MyModule do
        alias Foo.User
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_aliases(state, 3) == [{User, Foo.User}]
  end

  test "imports defined with v1.2 notation" do

    state =
      """
      defmodule MyModule do
        import Foo.Bar.{User, Email}
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_imports(state, 3) == [Foo.Bar.Email, Foo.Bar.User]
  end

  test "imports" do

    state =
      """
      defmodule OuterModule do
        import List
        IO.puts ""
        defmodule InnerModule do
          import Enum
          IO.puts ""
          def func do
            import String
            IO.puts ""
            if true do
              import Macro
              IO.puts ""
            end
            IO.puts ""
          end
          IO.puts ""
        end
        import Code
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_imports(state, 3)   == [List]
    assert get_line_imports(state, 6)   == [List, Enum]
    assert get_line_imports(state, 9)   == [List, Enum, String]
    assert get_line_imports(state, 12)  == [List, Enum, String, Macro]
    assert get_line_imports(state, 14)  == [List, Enum, String]
    assert get_line_imports(state, 16)  == [List, Enum]
    assert get_line_imports(state, 19)  == [Code, List]
  end

  test "requires" do

    state =
      """
      defmodule MyModule do
        require Mod
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_requires(state, 3)  == [Mod]
  end

  test "requires with 1.2 notation" do

    state =
      """
      defmodule MyModule do
        require Mod.{Mo1, Mod2}
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_requires(state, 3)  == [Mod.Mod2, Mod.Mo1]
  end

  test "current module" do

    state =
      """
      IO.puts ""
      defmodule OuterModule do
        IO.puts ""
        defmodule InnerModule do
          def func do
            if true do
              IO.puts ""
            end
          end
        end
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_module(state, 1)  == Elixir
    assert get_line_module(state, 3)  == OuterModule
    assert get_line_module(state, 7)  == OuterModule.InnerModule
    assert get_line_module(state, 11) == OuterModule
  end

  test "behaviours" do

    state =
      """
      IO.puts ""
      defmodule OuterModule do
        use Application
        @behaviour SomeModule.SomeBehaviour
        IO.puts ""
        defmodule InnerModuleWithUse do
          use GenServer
          IO.puts ""
        end
        defmodule InnerModuleWithBh do
          @behaviour SomeOtherBehaviour
          IO.puts ""
        end
        defmodule InnerModuleWithoutBh do
          IO.puts ""
        end
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_behaviours(state, 1)  == []
    assert get_line_behaviours(state, 5)  == [Application, SomeModule.SomeBehaviour]
    assert get_line_behaviours(state, 8)  == [GenServer]
    assert get_line_behaviours(state, 12)  == [SomeOtherBehaviour]
    assert get_line_behaviours(state, 15)  == []
    assert get_line_behaviours(state, 17)  == [Application, SomeModule.SomeBehaviour]
  end

  test "behaviour from erlang module" do

    state =
      """
      defmodule OuterModule do
        @behaviour :gen_server
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_line_behaviours(state, 3)  == [:gen_server]
  end

  test "current scope" do

    state =
      """
      defmodule MyModule do
        def func do
          IO.puts ""
        end
        IO.puts ""
        def func_with_when(par) when is_list(par) do
          IO.puts ""
        end
        IO.puts ""
        defmacro macro1(ast) do
          IO.puts ""
        end
        IO.puts ""
        defmacro import(module, opts)
        IO.puts ""
      end
      """
      |> string_to_state

    assert get_scope_name(state, 3) == {:func, 0}
    assert get_scope_name(state, 5) == :MyModule
    assert get_scope_name(state, 7) == {:func_with_when, 1}
    assert get_scope_name(state, 9) == :MyModule
    assert get_scope_name(state, 11) == {:macro1, 1}
    assert get_scope_name(state, 13) == :MyModule
    assert get_scope_name(state, 15) == :MyModule
  end

  defp string_to_state(string) do
    string
    |> Code.string_to_quoted
    |> (fn {:ok, ast} -> ast end).()
    |> MetadataBuilder.build
  end

  defp get_scope_name(state, line) do
    case state.lines_to_env[line] do
      nil -> nil
      env -> env.scope
    end
  end

  defp get_line_vars(state, line) do
    case state.lines_to_env[line] do
      nil -> []
      env -> env.vars
    end |> Enum.sort
  end

  defp get_line_aliases(state, line) do
    case state.lines_to_env[line] do
      nil -> []
      env -> env.aliases
    end
  end

  defp get_line_imports(state, line) do
    case state.lines_to_env[line] do
      nil -> []
      env -> env.imports
    end
  end

  defp get_line_requires(state, line) do
    case state.lines_to_env[line] do
      nil -> []
      env -> env.requires
    end
  end

  defp get_line_attributes(state, line) do
    case state.lines_to_env[line] do
      nil -> []
      env -> env.attributes
    end |> Enum.sort
  end

  defp get_line_behaviours(state, line) do
    case state.lines_to_env[line] do
      nil -> []
      env -> env.behaviours
    end |> Enum.sort
  end

  defp get_line_module(state, line) do
    (env = state.lines_to_env[line]) && env.module
  end

  defp get_subject_definition_line(module, func, arity) do
    file = module.module_info(:compile)[:source]
    acc =
      File.read!(file)
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    %{lines: lines} = Map.get(acc.mods_funs_to_lines, {module, func, arity})
    line_number = List.last(lines)

    File.read!(file) |> String.split("\n") |> Enum.at(line_number-1)
  end

end
