defmodule ElixirSense.SuggestionsTest do

  use ExUnit.Case

  test "empty hint" do
    buffer = """
    defmodule MyModule do

    end
    """

    list = ElixirSense.suggestions(buffer, 2, 7)

    assert Enum.find(list, fn s -> match?(%{name: "import", arity: 2}, s) end) == %{
      args: "module,opts", arity: 2, name: "import",
      origin: "Kernel.SpecialForms", spec: "",
      summary: "Imports functions and macros from other modules.",
      type: "macro"
    }
    assert Enum.find(list, fn s -> match?(%{name: "quote", arity: 2}, s) end) == %{
      arity: 2, origin: "Kernel.SpecialForms",
      spec: "", type: "macro", args: "opts,block",
      name: "quote",
      summary: "Gets the representation of any expression."
    }
    assert Enum.find(list, fn s -> match?(%{name: "require", arity: 2}, s) end) == %{
      arity: 2, origin: "Kernel.SpecialForms",
      spec: "", type: "macro", args: "module,opts",
      name: "require",
      summary: "Requires a module in order to use its macros."
    }

  end

  test "without empty hint" do

    buffer = """
    defmodule MyModule do
      is_b
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 11)

    assert list == [
      %{type: :hint, value: "is_b"},
      %{args: "term", arity: 1, name: "is_binary", origin: "Kernel",
        spec: "@spec is_binary(term) :: boolean",
        summary: "Returns `true` if `term` is a binary; otherwise returns `false`.",
        type: "function"},
      %{args: "term", arity: 1, name: "is_bitstring", origin: "Kernel",
        spec: "@spec is_bitstring(term) :: boolean",
        summary: "Returns `true` if `term` is a bitstring (including a binary); otherwise returns `false`.",
        type: "function"},
      %{args: "term", arity: 1, name: "is_boolean", origin: "Kernel",
        spec: "@spec is_boolean(term) :: boolean",
        summary: "Returns `true` if `term` is either the atom `true` or the atom `false` (i.e.,\na boolean); otherwise returns `false`.",
        type: "function"}
      ]
  end

  test "with an alias" do
    buffer = """
    defmodule MyModule do
      alias List, as: MyList
      MyList.flat
    end
    """

    list = ElixirSense.suggestions(buffer, 3, 14)

    assert list  == [
      %{type: :hint, value: "MyList.flatten"},
      %{args: "list,tail", arity: 2, name: "flatten", origin: "List",
       spec: "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var",
       summary: "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
       type: "function"},
      %{args: "list", arity: 1, name: "flatten", origin: "List",
       spec: "@spec flatten(deep_list) :: list when deep_list: [any | deep_list]",
       summary: "Flattens the given `list` of nested lists.",
       type: "function"}
    ]
  end

  test "with a module hint" do
    buffer = """
    defmodule MyModule do
      Str
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 6)

    assert list == [
      %{type: :hint, value: "Str"},
      %{name: "Stream", subtype: :struct,
       summary: "Module for creating and composing streams.",
       type: :module},
      %{name: "String", subtype: nil,
       summary: "A String in Elixir is a UTF-8 encoded binary.",
       type: :module},
      %{name: "StringIO", subtype: nil,
       summary: "Controls an IO device process that wraps a string.",
       type: :module}
    ]
  end

  test "lists callbacks" do
    buffer = """
    defmodule MyServer do
      use GenServer

    end
    """

    list =
      ElixirSense.suggestions(buffer, 3, 7)
      |> Enum.filter(fn s -> s.type == :callback && s.name == :code_change end)

    assert list == [%{
      args: "old_vsn,state,extra", arity: 3, name: :code_change,
      origin: "GenServer",
      spec: "@callback code_change(old_vsn, state :: term, extra :: term) ::\n  {:ok, new_state :: term} |\n  {:error, reason :: term} when old_vsn: term | {:down, term}\n",
      summary: "Invoked to change the state of the `GenServer` when a different version of a\nmodule is loaded (hot code swapping) and the state's term structure should be\nchanged.",
      type: :callback
    }]
  end

  test "lists returns" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def handle_call(request, from, state) do

      end

    end
    """

    list =
      ElixirSense.suggestions(buffer, 5, 5)
      |> Enum.filter(fn s -> s.type == :return end)

    assert list == [
      %{description: "{:reply, reply, new_state}",
       snippet: "{:reply, \"${1:reply}$\", \"${2:new_state}$\"}",
       spec: "{:reply, reply, new_state} when reply: term, new_state: term, reason: term",
       type: :return},
      %{description: "{:reply, reply, new_state, timeout | :hibernate}",
        snippet: "{:reply, \"${1:reply}$\", \"${2:new_state}$\", \"${3:timeout | :hibernate}$\"}",
        spec: "{:reply, reply, new_state, timeout | :hibernate} when reply: term, new_state: term, reason: term",
        type: :return},
      %{description: "{:noreply, new_state}",
        snippet: "{:noreply, \"${1:new_state}$\"}",
        spec: "{:noreply, new_state} when reply: term, new_state: term, reason: term",
        type: :return},
      %{description: "{:noreply, new_state, timeout | :hibernate}",
        snippet: "{:noreply, \"${1:new_state}$\", \"${2:timeout | :hibernate}$\"}",
        spec: "{:noreply, new_state, timeout | :hibernate} when reply: term, new_state: term, reason: term",
        type: :return},
      %{description: "{:stop, reason, reply, new_state}",
        snippet: "{:stop, \"${1:reason}$\", \"${2:reply}$\", \"${3:new_state}$\"}",
        spec: "{:stop, reason, reply, new_state} when reply: term, new_state: term, reason: term",
        type: :return},
      %{description: "{:stop, reason, new_state}",
        snippet: "{:stop, \"${1:reason}$\", \"${2:new_state}$\"}",
        spec: "{:stop, reason, new_state} when reply: term, new_state: term, reason: term",
        type: :return}
    ]
  end

  test "lists params and vars" do
    buffer = """
    defmodule MyServer do
      use GenServer

      def handle_call(request, from, state) do
        var1 = true

      end

    end
    """

    list =
      ElixirSense.suggestions(buffer, 6, 5)
      |> Enum.filter(fn s -> s.type == :variable end)

    assert list == [
      %{name: :from, type: :variable},
      %{name: :request, type: :variable},
      %{name: :state, type: :variable},
      %{name: :var1, type: :variable}
    ]
  end

  test "lists attributes" do
    buffer = """
    defmodule MyModule do
      @my_attribute1 true
      @my_attribute2 false
      @
    end
    """

    list =
      ElixirSense.suggestions(buffer, 4, 4)
      |> Enum.filter(fn s -> s.type == :attribute end)

    assert list == [
      %{name: "@my_attribute1", type: :attribute},
      %{name: "@my_attribute2", type: :attribute}
    ]
  end

  test "Elixir module" do
    buffer = """
    defmodule MyModule do
      El
    end
    """

    list = ElixirSense.suggestions(buffer, 2, 5)

    assert Enum.at(list,0) == %{type: :hint, value: "Elixir"}
    assert Enum.at(list,1) == %{type: :module, name: "Elixir", subtype: nil, summary: ""}
  end

end
