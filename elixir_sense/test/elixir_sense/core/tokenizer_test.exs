defmodule ElixirSense.Core.TokenizerTest do
  use ExUnit.Case

  alias ElixirSense.Core.Tokenizer

  describe "tokenize/1" do
    test "functions wihtout namespace" do
      assert Tokenizer.tokenize("var = func(") ==
               [
                 {:"(", {1, 11, nil}},
                 {:paren_identifier, {1, 7, nil}, :func},
                 {:match_op, {1, 5, nil}, :=},
                 {:identifier, {1, 1, nil}, :var}
               ]
    end

    test "functions with namespace" do
      assert Tokenizer.tokenize("var = Mod.func(param1, par") == [
               {:identifier, {1, 24, nil}, :par},
               {:",", {1, 22, 0}},
               {:identifier, {1, 16, nil}, :param1},
               {:"(", {1, 15, nil}},
               {:paren_identifier, {1, 11, nil}, :func},
               {:., {1, 10, nil}},
               {:alias, {1, 7, nil}, :Mod},
               {:match_op, {1, 5, nil}, :=},
               {:identifier, {1, 1, nil}, :var}
             ]

      assert Tokenizer.tokenize("var = Mod.SubMod.func(param1, param2, par") == [
               {:identifier, {1, 39, nil}, :par},
               {:",", {1, 37, 0}},
               {:identifier, {1, 31, nil}, :param2},
               {:",", {1, 29, 0}},
               {:identifier, {1, 23, nil}, :param1},
               {:"(", {1, 22, nil}},
               {:paren_identifier, {1, 18, nil}, :func},
               {:., {1, 17, nil}},
               {:alias, {1, 11, nil}, :SubMod},
               {:., {1, 10, nil}},
               {:alias, {1, 7, nil}, :Mod},
               {:match_op, {1, 5, nil}, :=},
               {:identifier, {1, 1, nil}, :var}
             ]
    end

    test "at the beginning of a defmodule" do
      assert Tokenizer.tokenize("defmo") == [{:identifier, {1, 1, nil}, :defmo}]
    end
  end
end
