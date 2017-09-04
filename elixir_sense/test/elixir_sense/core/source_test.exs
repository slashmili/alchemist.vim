defmodule ElixirSense.Core.SourceTest do
  use ExUnit.Case

  import ElixirSense.Core.Source

  describe "which_func/1" do

    test "functions without namespace" do
      assert which_func("var = func(") == %{
        candidate: {nil, :func},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 11}}
      }
      assert which_func("var = func(param1, ") == %{
        candidate: {nil, :func},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 11}}
      }
    end

    test "functions with namespace" do
      assert which_func("var = Mod.func(param1, par") == %{
        candidate: {Mod, :func},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
      assert which_func("var = Mod.SubMod.func(param1, param2, par") == %{
        candidate: {Mod.SubMod, :func},
        npar: 2,
        pipe_before: false,
        pos: {{1, 7}, {1, 22}}
      }
    end

    test "nested functions calls" do
      assert which_func("var = outer_func(Mod.SubMod.func(param1,") == %{
        candidate: {Mod.SubMod, :func},
        npar: 1,
        pipe_before: false,
        pos: {{1, 18}, {1, 33}}
      }
      assert which_func("var = outer_func(Mod.SubMod.func(param1, [inner_func(") == %{
        candidate: {nil, :inner_func},
        npar: 0,
        pipe_before: false,
        pos: {{1, 43}, {1, 53}}
      }
      assert which_func("var = outer_func(func(param1, inner_func, ") == %{
        candidate: {nil, :func},
        npar: 2,
        pipe_before: false,
        pos: {{1, 18}, {1, 22}}
      }
      assert which_func("var = outer_func(func(param1, inner_func(), ") == %{
        candidate: {nil, :func},
        npar: 2,
        pipe_before: false,
        pos: {{1, 18}, {1, 22}}
      }
      assert which_func("var = func(param1, func2(fun(p3), 4, 5), func3(p1, p2), ") == %{
        candidate: {nil, :func},
        npar: 3,
        pipe_before: false,
        pos: {{1, 7}, {1, 11}}
      }
    end

    test "function call with multiple lines" do
      assert which_func("""
        var = Mod.func(param1,
          param2,

        """) == %{candidate: {Mod, :func}, npar: 2, pipe_before: false, pos: {{1, 7}, {1, 15}}}
    end

    test "after double quotes" do
      assert which_func("var = func(param1, \"not_a_func(, ") == %{
        candidate: {nil, :func},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 11}}
      }
      assert which_func("var = func(\"a_string_(param1\", ") == %{
        candidate: {nil, :func},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 11}}
      }
    end

    test "with operators" do
      assert which_func("var = Mod.func1(param) + func2(param1, ") == %{
        candidate: {nil, :func2},
        npar: 1,
        pipe_before: false,
        pos: {{1, 26}, {1, 31}}
      }
    end

    test "erlang functions" do
      assert which_func("var = :global.whereis_name( ") == %{
        candidate: {:global, :whereis_name},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 27}}
      }
    end

    test "with fn" do
      assert which_func("fn(a, ") == %{candidate: :none, npar: 0, pipe_before: false, pos: nil}
    end

    test "with another fn before" do
      assert which_func("var = Enum.sort_by(list, fn(i) -> i*i end, fn(a, ") == %{
        candidate: {Enum, :sort_by},
        npar: 2,
        pipe_before: false,
        pos: {{1, 7}, {1, 19}}
      }
    end

    test "inside fn body" do
      assert which_func("var = Enum.map([1,2], fn(i) -> i*") == %{
        candidate: {Enum, :map},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a list" do
      assert which_func("var = Enum.map([1,2,3") == %{
        candidate: {Enum, :map},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a list after comma" do
      assert which_func("var = Enum.map([1,") == %{
        candidate: {Enum, :map},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside an list without items" do
      assert which_func("var = Enum.map([") == %{
        candidate: {Enum, :map},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a list with a list before" do
      assert which_func("var = Enum.map([1,2], [1, ") == %{
        candidate: {Enum, :map},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a tuple" do
      assert which_func("var = Enum.map({1,2,3") == %{
        candidate: {Enum, :map},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a tuple with another tuple before" do
      assert which_func("var = Enum.map({1,2}, {1, ") == %{
        candidate: {Enum, :map},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a tuple inside a list" do
      assert which_func("var = Enum.map({1,2}, [{1, ") == %{
        candidate: {Enum, :map},
        npar: 1,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a tuple after comma" do
      assert which_func("var = Enum.map([{1,") == %{
        candidate: {Enum, :map},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "inside a list inside a tuple inside a list" do
      assert which_func("var = Enum.map([{1,[a, ") == %{
        candidate: {Enum, :map},
        npar: 0,
        pipe_before: false,
        pos: {{1, 7}, {1, 15}}
      }
    end

    test "fails when code has parsing errors before the cursor" do
      assert which_func("} = Enum.map(list, ") == %{candidate: :none, npar: 0, pipe_before: false, pos: nil}
    end

  end

  describe "text_before/3" do

    test "functions without namespace" do
      code = """
      defmodule MyMod do
        def my_func(par1, )
      end
      """
      text = """
      defmodule MyMod do
        def my_func(par1,
      """ |> String.trim()

      assert text_before(code, 2, 20) == text
    end

  end
  describe "subject" do

    test "functions without namespace" do
      code = """
      defmodule MyMod do
        my_func(par1, )
      end
      """

      assert subject(code, 2, 5) == "my_func"
    end

    test "functions with namespace" do
      code = """
      defmodule MyMod do
        Mod.func(par1, )
      end
      """

      assert subject(code, 2, 8) == "Mod.func"
    end

    test "functions ending with !" do
      code = """
      defmodule MyMod do
        Mod.func!
      end
      """

      assert subject(code, 2, 8) == "Mod.func!"
    end

    test "functions ending with ?" do
      code = """
      defmodule MyMod do
        func?(par1, )
      end
      """

      assert subject(code, 2, 8) == "func?"
    end

    test "erlang modules" do
      code = """
        :lists.concat([1,2])
      """

      assert subject(code, 1, 5) == ":lists"
      assert subject(code, 1, 5) == ":lists"
    end

    test "functions from erlang modules" do
      code = """
        :lists.concat([1,2])
      """

      assert subject(code, 1, 12) == ":lists.concat"
    end

    test "capture operator" do
      code = """
        Emum.map(list, &func/1)
      """

      assert subject(code, 1, 21) == "func"
    end

    test "functions with `!` operator before" do
      code = """
        if !match({_,_}, var) do
      """

      assert subject(code, 1, 8) == "match"
    end

    test "module and function in different lines" do
      code = """
        Mod.
          func
      """

      assert subject(code, 2, 7) == "Mod.func"
    end

    test "elixir module" do
      code = """
      defmodule MyMod do
        ModA.ModB.func
      end
      """

      assert subject(code, 2, 4)  == "ModA"
      assert subject(code, 2, 9)  == "ModA.ModB"
      assert subject(code, 2, 14) == "ModA.ModB.func"
    end

    test "anonymous functions call" do
      code = """
        my_func.(1,2)
      """

      assert subject(code, 1, 4) == "my_func"
    end

    test "no empty/stop grapheme after subject" do
      code = "Mod.my_func"

      assert subject(code, 1, 2) == "Mod"
      assert subject(code, 1, 6) == "Mod.my_func"
    end

    test "find closest on the edges" do
      code = """
      defmodule MyMod do
        Mod.my_func(par1, par2)
      end
      """

      assert subject(code, 2, 2) == nil
      assert subject(code, 2, 3) == "Mod"
      assert subject(code, 2, 5) == "Mod"
      assert subject(code, 2, 6) == "Mod"
      assert subject(code, 2, 7) == "Mod.my_func"
      assert subject(code, 2, 14) == "Mod.my_func"
      assert subject(code, 2, 15) == "par1"
      assert subject(code, 2, 19) == "par1"
      assert subject(code, 2, 20) == nil
      assert subject(code, 2, 21) == "par2"
    end

    test "module from struct" do
      code = """
      defmodule MyMod do
        Mod.my_func(%MyMod{a: 1})
      end
      """

      assert subject(code, 2, 17) == "MyMod"
    end

  end
end
