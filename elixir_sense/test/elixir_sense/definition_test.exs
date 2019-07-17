defmodule ElixirSense.Providers.DefinitionTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Definition
  alias ElixirSense.Providers.Definition.Location

  doctest Definition

  test "find definition of aliased modules in `use`" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.UseExample
      use UseExample
      #        ^
    end
    """
    %{found: true, type: :module, file: file, line: line, column: column} = ElixirSense.definition(buffer, 3, 12)
    assert file =~ "elixir_sense/test/support/use_example.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.UseExample"
  end

  @tag requires_source: true
  test "find definition of functions from Kernel" do
    buffer = """
    defmodule MyModule do
    #^
    end
    """
    %{found: true, type: :function, file: file, line: line, column: column} = ElixirSense.definition(buffer, 1, 2)
    assert file =~ "lib/elixir/lib/kernel.ex"
    assert read_line(file, {line, column}) =~ "defmodule("
  end

  @tag requires_source: true
  test "find definition of functions from Kernel.SpecialForms" do
    buffer = """
    defmodule MyModule do
      import List
       ^
    end
    """
    %{found: true, type: :function, file: file, line: line, column: column} = ElixirSense.definition(buffer, 2, 4)
    assert file =~ "lib/elixir/lib/kernel/special_forms.ex"
    assert read_line(file, {line, column}) =~ "import"
  end

  test "find definition of functions from imports" do
    buffer = """
    defmodule MyModule do
      import ElixirSenseExample.ModuleWithFunctions
      function_arity_zero()
      #^
    end
    """
    %{found: true, type: :function, file: file, line: line, column: column} = ElixirSense.definition(buffer, 3, 4)
    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_zero"
  end

  test "find definition of functions from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.function_arity_one(42)
      #        ^
    end
    """
    %{found: true, type: :function, file: file, line: line, column: column} = ElixirSense.definition(buffer, 3, 11)
    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "function_arity_one"
  end

  test "find definition of delegated functions" do
    buffer = """
    defmodule MyModule do
      alias ElixirSenseExample.ModuleWithFunctions, as: MyMod
      MyMod.delegated_function()
      #        ^
    end
    """
    %{found: true, type: :function, file: file, line: line, column: column} = ElixirSense.definition(buffer, 3, 11)
    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "delegated_function"
  end

  test "find definition of modules" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      ElixirSenseExample.ModuleWithFunctions.function_arity_zero()
      #                   ^
    end
    """
    %{found: true, type: :module, file: file, line: line, column: column} = ElixirSense.definition(buffer, 3, 23)
    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
    assert read_line(file, {line, column}) =~ "ElixirSenseExample.ModuleWithFunctions do"
  end

  test "find definition of erlang modules" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
        # ^
      end
    end
    """

    %Location{found: true, type: :module, file: file, line: 1, column: 1} = ElixirSense.definition(buffer, 3, 7)
    assert file =~ "/src/lists.erl"
  end

  test "find definition of remote erlang functions" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
        #         ^
      end
    end
    """
    %{found: true, type: :function, file: file, line: line, column: column} = ElixirSense.definition(buffer, 3, 15)
    assert file =~ "/src/lists.erl"
    assert read_line(file, {line, column}) =~ "duplicate(N, X)"
  end

  test "non existing modules" do
    buffer = """
    defmodule MyModule do
      SilverBulletModule.run
    end
    """
    assert ElixirSense.definition(buffer, 2, 24) == %Location{found: false}
  end

  test "cannot find map field calls" do
    buffer = """
    defmodule MyModule do
      env = __ENV__
      IO.puts(env.file)
      #            ^
    end
    """
    assert ElixirSense.definition(buffer, 3, 16) == %Location{found: false}
  end

  test "cannot find map fields" do
    buffer = """
    defmodule MyModule do
      var = %{count: 1}
      #        ^
    end
    """
    assert ElixirSense.definition(buffer, 2, 12) == %Location{found: false}
  end

  test "preloaded modules" do
    buffer = """
    defmodule MyModule do
      :erlang.node
      # ^
    end
    """
    assert ElixirSense.definition(buffer, 2, 5) == %Location{found: false}
  end

  test "find the related module when searching for built-in functions" do
    # module_info is defined by default for every elixir and erlang module:
    # https://stackoverflow.com/a/33373107/175830
    buffer = """
    defmodule MyModule do
      ElixirSenseExample.ModuleWithFunctions.module_info()
      #                                      ^
    end
    """
    %{found: true, type: :function, file: file, line: 1, column: 1} = ElixirSense.definition(buffer, 2, 42)
    assert file =~ "elixir_sense/test/support/module_with_functions.ex"
  end

  test "find definition of variables" do
    buffer = """
    defmodule MyModule do
      def func do
        var1 = 1
        var2 = 2
        var1 = 3
        IO.puts(var1 + var2)
      end
    end
    """
    assert ElixirSense.definition(buffer, 6, 13) == %Location{found: true, type: :variable, file: nil, line: 3, column: 5}
    assert ElixirSense.definition(buffer, 6, 21) ==  %Location{found: true, type: :variable, file: nil, line: 4, column: 5}
  end

  test "find definition of params" do
    buffer = """
    defmodule MyModule do
      def func(%{a: [var2|_]}) do
        var1 = 3
        IO.puts(var1 + var2)
        #               ^
      end
    end
    """
    assert ElixirSense.definition(buffer, 4, 21) == %ElixirSense.Providers.Definition.Location{
      found: true,
      type: :variable,
      file: nil,
      line: 2,
      column: 18,
    }
  end

  defp read_line(file, {line, column}) do
    file
    |> File.read!
    |> String.split(["\n", "\r\n"])
    |> Enum.at(line-1)
    |> String.slice((column - 1)..-1)
  end

end
