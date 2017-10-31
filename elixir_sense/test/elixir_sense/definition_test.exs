defmodule ElixirSense.Providers.DefinitionTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Definition

  doctest Definition

  test "find definition of aliased modules in `use`" do
    buffer = """
    defmodule MyModule do
      alias Mix.Generator
      use Generator
    end
    """
    {file, line} = ElixirSense.definition(buffer, 3, 12)
    assert file =~ "lib/mix/lib/mix/generator.ex"
    assert read_line(file, line) =~ "defmodule Mix.Generator"
  end

  test "find definition of functions from Kernel" do
    buffer = """
    defmodule MyModule do

    end
    """
    {file, line} = ElixirSense.definition(buffer, 1, 2)
    assert file =~ "lib/elixir/lib/kernel.ex"
    assert read_line(file, line) =~ "defmacro defmodule"
  end

  test "find definition of functions from Kernel.SpecialForms" do
    buffer = """
    defmodule MyModule do
      import List
    end
    """
    {file, line} = ElixirSense.definition(buffer, 2, 4)
    assert file =~ "lib/elixir/lib/kernel/special_forms.ex"
    assert read_line(file, line) =~ "defmacro import"
  end

  test "find definition of functions from imports" do
    buffer = """
    defmodule MyModule do
      import Mix.Generator
      create_file(
    end
    """
    {file, line} = ElixirSense.definition(buffer, 3, 4)
    assert file =~ "lib/mix/lib/mix/generator.ex"
    assert read_line(file, line) =~ "def create_file"
  end

  test "find definition of functions from aliased modules" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      MyList.flatten([[1],[3]])
    end
    """
    {file, line} = ElixirSense.definition(buffer, 3, 11)
    assert file =~ "lib/elixir/lib/list.ex"
    assert read_line(file, line) =~ "def flatten"
  end

  test "find definition of modules" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      String.to_atom("erlang")
    end
    """
    {file, line} = ElixirSense.definition(buffer, 3, 4)
    assert file =~ "lib/elixir/lib/string.ex"
    assert read_line(file, line) =~ "defmodule String"
  end

  test "find definition of erlang modules" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
      end
    end
    """
    {file, line} = ElixirSense.definition(buffer, 3, 7)
    assert file =~ "/src/lists.erl"
    assert line == 1
  end

  test "find definition of remote erlang functions" do
    buffer = """
    defmodule MyModule do
      def dup(x) do
        :lists.duplicate(2, x)
      end
    end
    """
    {file, line} = ElixirSense.definition(buffer, 3, 15)
    assert file =~ "/src/lists.erl"
    assert read_line(file, line) =~ "duplicate(N, X)"
  end

  test "non existing modules" do
    buffer = """
    defmodule MyModule do
      SilverBulletModule.run
    end
    """
    assert ElixirSense.definition(buffer, 2, 24) == {"non_existing", nil}
  end

  test "cannot find map field calls" do
    buffer = """
    defmodule MyModule do
      env = __ENV__
      IO.puts(env.file)
    end
    """
    assert ElixirSense.definition(buffer, 3, 16) == {"non_existing", nil}
  end

  test "cannot find vars" do
    buffer = """
    defmodule MyModule do
      var = 1
    end
    """
    assert ElixirSense.definition(buffer, 2, 4) == {"non_existing", nil}
  end

  test "cannot find map fields" do
    buffer = """
    defmodule MyModule do
      var = %{count: 1}
    end
    """
    assert ElixirSense.definition(buffer, 2, 12) == {"non_existing", nil}
  end

  test "preloaded modules" do
    buffer = """
    defmodule MyModule do
      :erlang.node
    end
    """
    assert ElixirSense.definition(buffer, 2, 5) == {"non_existing", nil}
  end

  # Call this when running `mix test`, but not when running `elixir run_test.exs`
  if Process.whereis(Elixir.Mix.Supervisor) do
    test "erlang modules from deps" do
      buffer = """
      defmodule MyModule do
        :hackney
      end
      """
      {file, line} = ElixirSense.definition(buffer, 2, 5)
      assert file =~ "deps/hackney/src/hackney.erl"
      assert line == 1
    end
  end

  test "find the related module when searching for built-in functions" do
    buffer = """
    defmodule MyModule do
      List.module_info()
    end
    """
    {file, line} = ElixirSense.definition(buffer, 2, 10)
    assert file =~ "lib/elixir/lib/list.ex"
    assert line == nil
  end

  defp read_line(file, line) do
    file
    |> File.read!
    |> String.split(["\n", "\r\n"])
    |> Enum.at(line-1)
    |> String.trim
  end

end
