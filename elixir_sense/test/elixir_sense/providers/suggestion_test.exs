defmodule ElixirSense.Providers.SuggestionTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Suggestion

  doctest Suggestion

  defmodule MyModule do
    def say_hi, do: true
  end

  test "find definition of functions from Kernel" do
      assert [
        %{type: :hint, value: "List."},
        %{name: "List", subtype: nil, summary: "" <> _, type: :module},
        %{name: "Chars", subtype: :protocol, summary: "The List.Chars protocol" <> _, type: :module},
        %{args: "", arity: 1, name: "__info__", origin: "List", spec: nil, summary: "", type: "function"},
        %{args: "list", arity: 1, name: "first", origin: "List", spec: "@spec first([elem]) :: nil | elem when elem: var", summary: "Returns the first " <> _, type: "function"},
        %{args: "list", arity: 1, name: "last", origin: "List", spec: "@spec last([elem]) :: nil | elem when elem: var", summary: "Returns the last element " <> _, type: "function"},
        %{args: "charlist", arity: 1, name: "to_atom", origin: "List", spec: "@spec to_atom(charlist) :: atom", summary: "Converts a charlist to an atom.", type: "function"},
        %{args: "charlist", arity: 1, name: "to_existing_atom", origin: "List", spec: "@spec to_existing_atom(charlist) :: atom", summary: "Converts a charlist" <> _, type: "function"},
        %{args: "charlist", arity: 1, name: "to_float", origin: "List", spec: "@spec to_float(charlist) :: float", summary: "Returns the float " <> _, type: "function"},
        %{args: "list", arity: 1, name: "to_string", origin: "List", spec: "@spec to_string(:unicode.charlist) :: String.t", summary: "Converts a list " <> _, type: "function"},
        %{args: "list", arity: 1, name: "to_tuple", origin: "List", spec: "@spec to_tuple(list) :: tuple", summary: "Converts a list to a tuple.", type: "function"},
        %{args: "list", arity: 1, name: "wrap", origin: "List", spec: "@spec wrap(list | any) :: list", summary: "Wraps the " <> _, type: "function"},
        %{args: "list_of_lists", arity: 1, name: "zip", origin: "List", spec: "@spec zip([list]) :: [tuple]", summary: "Zips corresponding " <> _, type: "function"},
        %{args: "", arity: 1, name: "module_info", origin: "List", spec: nil, summary: "", type: "function"},
        %{args: "", arity: 0, name: "module_info", origin: "List", spec: nil, summary: "", type: "function"},
        %{args: "list,item", arity: 2, name: "delete", origin: "List", spec: "@spec delete(list, any) :: list", summary: "Deletes the given " <> _, type: "function"}
      | _] = Suggestion.find("List", [], [], [], [], [], SomeModule)
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
