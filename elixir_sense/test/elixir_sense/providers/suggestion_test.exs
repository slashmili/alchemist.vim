defmodule ElixirSense.Providers.SuggestionTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Suggestion

  doctest Suggestion

  defmodule MyModule do
    def say_hi, do: true
  end

  test "find definition of functions from Kernel" do
    result = Suggestion.find("List", [], [], [], [], [], SomeModule) |> Enum.take(16)
    assert result |> Enum.at(0) == %{type: :hint, value: "List."}
    assert result |> Enum.at(1) == %{name: "List", subtype: nil, summary: "Functions that work on (linked) lists.", type: :module}
    assert result |> Enum.at(3) == %{args: "", arity: 1, name: "__info__", origin: "List", spec: nil, summary: "", type: "function"}
    assert result |> Enum.at(4) == %{args: "list", arity: 1, name: "first", origin: "List", spec: "@spec first([elem]) :: nil | elem when elem: var", summary: "Returns the first element in `list` or `nil` if `list` is empty.", type: "function"}
    assert result |> Enum.at(5) == %{args: "list", arity: 1, name: "last", origin: "List", spec: "@spec last([elem]) :: nil | elem when elem: var", summary: "Returns the last element in `list` or `nil` if `list` is empty.", type: "function"}
    assert result |> Enum.at(13) == %{args: "", arity: 1, name: "module_info", origin: "List", spec: nil, summary: "", type: "function"}
    assert result |> Enum.at(15) == %{args: "list,item", arity: 2, name: "delete", origin: "List", spec: "@spec delete(list, any) :: list", summary: "Deletes the given `item` from the `list`. Returns a new list without\nthe item.", type: "function"}
  end

  test "return completion candidates for 'Str'" do
    assert Suggestion.find("Str", [], [], [], [], [], SomeModule) == [
      %{type: :hint, value: "Str"},
      %{name: "Stream", subtype: :struct, summary: "Module for creating and composing streams.", type: :module},
      %{name: "String", subtype: nil, summary: "A String in Elixir is a UTF-8 encoded binary.", type: :module},
      %{name: "StringIO", subtype: nil, summary: "Controls an IO device process that wraps a string.", type: :module}
    ]
  end

  test "return completion candidates for 'List.del'" do
    assert [
      %{type: :hint, value: "List.delete"},
      %{args: "list,item", arity: 2, name: "delete", origin: "List", spec: "@spec delete(list, any) :: list", summary: "Deletes the given" <> _, type: "function"},
      %{args: "list,index", arity: 2, name: "delete_at", origin: "List", spec: "@spec delete_at(list, integer) :: list", summary: "Produces a new list by " <> _, type: "function"}
    ] = Suggestion.find("List.del", [], [], [], [], [], SomeModule)
  end

  test "return completion candidates for module with alias" do
    assert [
      %{type: :hint, value: "MyList.delete"},
      %{args: "list,item", arity: 2, name: "delete", origin: "List", spec: "@spec delete(list, any) :: list", summary: "Deletes the given " <> _, type: "function"},
      %{args: "list,index", arity: 2, name: "delete_at", origin: "List", spec: "@spec delete_at(list, integer) :: list", summary: "Produces a new list " <> _, type: "function"}
    ] = Suggestion.find("MyList.del", [], [{MyList, List}], [], [], [], SomeModule)
  end

  test "return completion candidates for functions from import" do
    assert Suggestion.find("say", [MyModule], [], [], [], [], SomeModule) == [
      %{type: :hint, value: "say"},
      %{args: "", arity: 0, name: "say_hi", origin: "ElixirSense.Providers.SuggestionTest.MyModule", spec: "", summary: "", type: "public_function"}
    ]
  end

end
