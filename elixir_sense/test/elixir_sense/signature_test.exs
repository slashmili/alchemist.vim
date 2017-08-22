defmodule ElixirSense.SignatureTest do

  use ExUnit.Case
  alias ElixirSense.Providers.Signature

  doctest Signature

  describe "signature" do

    test "find signatures from aliased modules" do
      code = """
      defmodule MyModule do
        alias List, as: MyList
        MyList.flatten(par1,
      end
      """
      assert ElixirSense.signature(code, 3, 23) == %{
        active_param: 1,
        pipe_before: false,
        signatures: [
          %{
            name: "flatten",
            params: ["list"],
            documentation: "Flattens the given `list` of nested lists.",
            spec: "@spec flatten(deep_list) :: list when deep_list: [any | deep_list]"
          },
          %{
            name: "flatten",
            params: ["list", "tail"],
            documentation: "Flattens the given `list` of nested lists.\nThe list `tail` will be added at the end of\nthe flattened list.",
            spec: "@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var"
          }
        ]
      }
    end

    test "finds signatures from Kernel functions" do
      code = """
      defmodule MyModule do
        apply(par1,
      end
      """
      assert ElixirSense.signature(code, 2, 14) == %{
        active_param: 1,
        pipe_before: false,
        signatures: [
          %{
            name: "apply",
            params: ["fun", "args"],
            documentation: "Invokes the given `fun` with the list of arguments `args`.",
            spec: "@spec apply((... -> any), [any]) :: any"
          },
          %{
            name: "apply",
            params: ["module", "fun", "args"],
            documentation: "Invokes the given `fun` from `module` with the list of arguments `args`.",
            spec: "@spec apply(module, atom, [any]) :: any"
          }
        ]
      }
    end

    test "finds signatures from local functions" do
      code = """
      defmodule MyModule do

        def run do
          sum(a,
        end

        defp sum(a, b) do
          a + b
        end

        defp sum({a, b}) do
          a + b
        end
      end
      """
      assert ElixirSense.signature(code, 4, 12) == %{
        active_param: 1,
        pipe_before: false,
        signatures: [
          %{
            name: "sum",
            params: ["a", "b"],
            documentation: "",
            spec: ""
          },
          %{
            name: "sum",
            params: ["tuple"],
            documentation: "",
            spec: ""
          }
        ]
      }
    end

    test "returns :none when it cannot identify a function call" do
      code = """
      defmodule MyModule do
        fn(a,
      end
      """
      assert ElixirSense.signature(code, 2, 8) == :none
    end

    test "return empty signature list when no signature is found" do
      code = """
      defmodule MyModule do
        a_func(
      end
      """
      assert ElixirSense.signature(code, 2, 10) == %{active_param: 0, signatures: [], pipe_before: false}
    end

    test "after |>" do
      code = """
      defmodule MyModule do
        {1, 2} |> IO.inspect(
      end
      """
      assert ElixirSense.signature(code, 2, 24) == %{
        active_param: 1,
        pipe_before: true,
        signatures: [
          %{
            name: "inspect",
            params: ["item", "opts \\\\ []"],
            documentation: "Inspects and writes the given `item` to the device.",
            spec: "@spec inspect(item, keyword) :: item when item: var"
          },
          %{
            name: "inspect",
            params: ["device", "item", "opts"],
            documentation: "Inspects `item` according to the given options using the IO `device`.",
            spec: "@spec inspect(device, item, keyword) :: item when item: var"
          }
        ]
      }
    end

  end

end
