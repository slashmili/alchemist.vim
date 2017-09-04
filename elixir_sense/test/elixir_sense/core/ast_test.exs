defmodule ElixirSense.Core.AstTest do

  use ExUnit.Case
  alias ElixirSense.Core.Ast

  defmodule ExpandRecursive do
    defmacro my_macro do
      quote do
        my_macro = "Hi"
      end
    end
  end

  test "expand_partial cannot expand recursive macros" do
    import ExpandRecursive
    result =
      quote do
        my_macro()
      end |> Ast.expand_partial(__ENV__)
    assert result == {:expand_error, "Cannot expand recursive macro"}
  end

  test "expand_all cannot expand recursive macros" do
    import ExpandRecursive
    result =
      quote do
        my_macro()
      end |> Ast.expand_all(__ENV__)
    assert result == {:expand_error, "Cannot expand recursive macro"}
  end

end
