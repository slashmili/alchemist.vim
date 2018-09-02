defmodule ElixirSense.Providers.ReferencesTest do

  use ExUnit.Case

  # doctest References

  test "find references with cursor over a function call" do
    buffer = """
    defmodule ElixirSense.Providers.ReferencesTest.Caller2 do
      def func() do
        ElixirSense.Providers.ReferencesTest.Callee.func()
      end
    end
    """
    references = ElixirSense.references(buffer, 3, 52)

    assert references == [
      %{
        range: %{end: %{character: 0, line: 12}, start: %{character: 0, line: 12}},
        uri: "lib/elixir_sense/providers/references_test_modules.ex"
      },
      %{
        range: %{end: %{character: 0, line: 17}, start: %{character: 0, line: 17}},
        uri: "lib/elixir_sense/providers/references_test_modules.ex"
      }
    ]
  end

  test "find references with cursor over a function definition" do
    buffer = """
    defmodule ElixirSense.Providers.ReferencesTest.Callee do
      def func() do
        IO.puts ""
      end
      def func(par1) do
        IO.puts par1
      end
    end
    """
    references = ElixirSense.references(buffer, 2, 10)
    assert references == [
      %{
        range: %{end: %{character: 0, line: 12}, start: %{character: 0, line: 12}},
        uri: "lib/elixir_sense/providers/references_test_modules.ex"
      }
    ]

    references = ElixirSense.references(buffer, 5, 10)
    assert references == [
      %{
        range: %{end: %{character: 0, line: 17}, start: %{character: 0, line: 17}},
        uri: "lib/elixir_sense/providers/references_test_modules.ex"
      }
    ]
  end

  test "with aliased modules" do
    buffer = """
    defmodule ElixirSense.Providers.ReferencesTest.Caller2 do
      def func() do
        alias ElixirSense.Providers.ReferencesTest.Callee, as: C
        C.func()
      end
    end
    """
    references = ElixirSense.references(buffer, 4, 10)

    assert references == [
      %{
        range: %{end: %{character: 0, line: 12}, start: %{character: 0, line: 12}},
        uri: "lib/elixir_sense/providers/references_test_modules.ex"
      },
      %{
        range: %{end: %{character: 0, line: 17}, start: %{character: 0, line: 17}},
        uri: "lib/elixir_sense/providers/references_test_modules.ex"
      }
    ]
  end

  test "find references of variables" do
    buffer = """
    defmodule MyModule do
      def func do
        var1 = 1
        var2 = 2
        var1 = 3
        IO.puts(var1 + var2)
      end
      def func4(ppp) do

      end
    end
    """
    # references = ElixirSense.references(buffer, 3, 6)
    references = ElixirSense.references(buffer, 6, 13)

    assert references == [
      %{uri: nil, range: %{start: %{line: 3, character: 5}, end: %{line: 3, character: 9}}},
      %{uri: nil, range: %{start: %{line: 5, character: 5}, end: %{line: 5, character: 9}}},
      %{uri: nil, range: %{start: %{line: 6, character: 13}, end: %{line: 6, character: 17}}},
    ]
  end

end
