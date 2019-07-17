defmodule ElixirSense.Providers.SuggestionTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Suggestion

  doctest Suggestion

  defmodule MyModule do
    def say_hi, do: true
  end

  test "find definition of default functions" do
    result = Suggestion.find("ElixirSenseExample.EmptyModule", [], [], SomeModule, [], [], [], SomeModule, "") |> Enum.take(18)
    assert result |> Enum.at(0) == %{type: :hint, value: "ElixirSenseExample.EmptyModule."}
    assert result |> Enum.at(1) == %{
      name: "EmptyModule",
      subtype: nil,
      summary: "Empty module without other functions",
      type: :module
    }
    assert result |> Enum.at(2) == %{
      args: "",
      arity: 1,
      name: "__info__",
      origin: "ElixirSenseExample.EmptyModule",
      spec: nil,
      summary: "",
      type: "function"
    }
    assert result |> Enum.at(3) == %{
      args: "",
      arity: 1,
      name: "module_info",
      origin: "ElixirSenseExample.EmptyModule",
      spec: nil,
      summary: "",
      type: "function"
    }
    assert result |> Enum.at(4) == %{
      args: "",
      arity: 0,
      name: "module_info",
      origin: "ElixirSenseExample.EmptyModule",
      spec: nil,
      summary: "",
      type: "function"
    }
  end

  test "return completion candidates for 'Str'" do
    assert Suggestion.find("Str", [], [], SomeModule, [], [], [], SomeModule, "") == [
      %{type: :hint, value: "Str"},
      %{name: "Stream", subtype: :struct, summary: "Functions for creating and composing streams.", type: :module},
      %{name: "String", subtype: nil, summary: "A String in Elixir is a UTF-8 encoded binary.", type: :module},
      %{name: "StringIO", subtype: nil, summary: "Controls an IO device process that wraps a string.", type: :module}
    ]
  end

  test "return completion candidates for 'List.del'" do
    assert [
      %{type: :hint, value: "List.delete"},
      %{args: "list,item", arity: 2, name: "delete", origin: "List", spec: "@spec delete(list, any) :: list", summary: "Deletes the given" <> _, type: "function"},
      %{args: "list,index", arity: 2, name: "delete_at", origin: "List", spec: "@spec delete_at(list, integer) :: list", summary: "Produces a new list by " <> _, type: "function"}
    ] = Suggestion.find("List.del", [], [], SomeModule, [], [], [], SomeModule, "")
  end

  test "return completion candidates for module with alias" do
    assert [
      %{type: :hint, value: "MyList.delete"},
      %{args: "list,item", arity: 2, name: "delete", origin: "List", spec: "@spec delete(list, any) :: list", summary: "Deletes the given " <> _, type: "function"},
      %{args: "list,index", arity: 2, name: "delete_at", origin: "List", spec: "@spec delete_at(list, integer) :: list", summary: "Produces a new list " <> _, type: "function"}
    ] = Suggestion.find("MyList.del", [], [{MyList, List}], SomeModule, [], [], [], SomeModule, "")
  end

  test "return completion candidates for functions from import" do
    assert Suggestion.find("say", [MyModule], [], SomeModule, [], [], [], SomeModule, "") == [
      %{type: :hint, value: "say"},
      %{args: "", arity: 0, name: "say_hi", origin: "ElixirSense.Providers.SuggestionTest.MyModule", spec: "", summary: "", type: "public_function"}
    ]
  end

end
