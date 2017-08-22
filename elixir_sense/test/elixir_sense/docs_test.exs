defmodule ElixirSense.DocsTest do

  use ExUnit.Case

  describe "docs" do

    test "retrieve documentation" do
      buffer = """
      defmodule MyModule do

      end
      """

      %{
        subject: subject,
        actual_subject: actual_subject,
        docs: %{docs: docs}
      } = ElixirSense.docs(buffer, 1, 2)

      assert subject == "defmodule"
      assert actual_subject == "Kernel.defmodule"
      assert docs =~ """
      Defines a module given by name with the given contents.
      """
    end

    test "retrieve function documentation" do
      buffer = """
      defmodule MyModule do
        def func(list) do
          List.flatten(list)
        end
      end
      """

      %{
        subject: subject,
        actual_subject: actual_subject,
        docs: %{docs: docs}
      } = ElixirSense.docs(buffer, 3, 12)

      assert subject == "List.flatten"
      assert actual_subject == "List.flatten"
      assert docs == """
      > List.flatten(list)

      ### Specs

      `@spec flatten(deep_list) :: list when deep_list: [any | deep_list]`

      Flattens the given `list` of nested lists.

      ## Examples

          iex> List.flatten([1, [[2], 3]])
          [1, 2, 3]



      ____

      > List.flatten(list, tail)

      ### Specs

      `@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var`

      Flattens the given `list` of nested lists.
      The list `tail` will be added at the end of
      the flattened list.

      ## Examples

          iex> List.flatten([1, [[2], 3]], [4, 5])
          [1, 2, 3, 4, 5]

      """
    end

    test "retrieve function documentation from aliased modules" do
      buffer = """
      defmodule MyModule do
        alias List, as: MyList
        MyList.flatten
      end
      """

      %{
        subject: subject,
        actual_subject: actual_subject,
        docs: %{docs: docs}
      } = ElixirSense.docs(buffer, 3, 12)

      assert subject == "MyList.flatten"
      assert actual_subject == "List.flatten"
      assert docs == """
      > List.flatten(list)

      ### Specs

      `@spec flatten(deep_list) :: list when deep_list: [any | deep_list]`

      Flattens the given `list` of nested lists.

      ## Examples

          iex> List.flatten([1, [[2], 3]])
          [1, 2, 3]



      ____

      > List.flatten(list, tail)

      ### Specs

      `@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var`

      Flattens the given `list` of nested lists.
      The list `tail` will be added at the end of
      the flattened list.

      ## Examples

          iex> List.flatten([1, [[2], 3]], [4, 5])
          [1, 2, 3, 4, 5]

      """
    end

    test "retrive function documentation from imported modules" do
      buffer = """
      defmodule MyModule do
        import Mix.Generator
        create_file(
      end
      """

      %{
        subject: subject,
        actual_subject: actual_subject,
        docs: %{docs: docs}
      } = ElixirSense.docs(buffer, 3, 5)

      assert subject == "create_file"
      assert actual_subject == "Mix.Generator.create_file"
      assert docs =~ """
      > Mix.Generator.create_file(path, contents, opts \\\\\\\\ [])

      ### Specs

      `@spec create_file(Path.t, iodata, keyword) :: any`

      Creates a file with the given contents.
      If the file already exists, asks for user confirmation.

      ## Options

        * `:force` - forces installation without a shell prompt.

      ## Examples

          iex> Mix.Generator.create_file \".gitignore\", \"_build
      deps
      \"
          * creating .gitignore
          :ok

      """
    end

    test "request for defmacro" do
      buffer = """
      defmodule MyModule do
        defmacro my_macro do
        end
      end
      """

      %{subject: subject, docs: %{docs: docs}} = ElixirSense.docs(buffer, 2, 5)

      assert subject == "defmacro"
      assert docs =~ """
      > Kernel.defmacro(call, expr \\\\\\\\ nil)

      Defines a macro with the given name and body.

      Check `def/2` for rules on naming and default arguments.

      ## Examples

          defmodule MyLogic do
            defmacro unless(expr, opts) do
              quote do
                if !unquote(expr), unquote(opts)
              end
            end
          end

          require MyLogic
          MyLogic.unless false do
            IO.puts \"It works\"
          end

      """
    end

    test "retrieve documentation from modules" do
      buffer = """
      defmodule MyModule do
        use GenServer
      end
      """

      %{
        subject: subject,
        actual_subject: actual_subject,
        docs: %{docs: docs}
      } = ElixirSense.docs(buffer, 2, 8)

      assert subject == "GenServer"
      assert actual_subject == "GenServer"
      assert docs =~ """
      > GenServer

      A behaviour module for implementing the server of a client-server relation.

      A GenServer is a process like any other Elixir process and it can be used
      to keep state, execute code asynchronously and so on. The advantage of using
      a generic server process (GenServer) implemented using this module is that it
      will have a standard set of interface functions and include functionality for
      tracing and error reporting. It will also fit into a supervision tree.
      """
    end

    test "retrieve type information from modules" do
      buffer = """
      defmodule MyModule do
        use GenServer
      end
      """

      %{subject: subject, docs: %{types: docs}} = ElixirSense.docs(buffer, 2, 8)

      assert subject == "GenServer"
      assert docs =~ """
        `@type on_start ::
        {:ok, pid} |
        :ignore |
        {:error, {:already_started, pid} | term}
      `

        Return values of `start*` functions


      ____

        `@type name ::
        atom |
        {:global, term} |
        {:via, module, term}
      `

        The GenServer name
      """
    end

    test "retrieve callback information from modules" do
      buffer = """
      defmodule MyModule do
        use Application
      end
      """

      %{subject: subject, docs: %{callbacks: docs}} = ElixirSense.docs(buffer, 2, 8)

      assert subject == "Application"
      assert docs =~ """
        > start(start_type, start_args)

        ### Specs

        `@callback start(start_type, start_args :: term) ::
        {:ok, pid} |
        {:ok, pid, state} |
        {:error, reason :: term}
      `

        Called when an application is started.
      """
    end

    test "no docs" do
      buffer = """
      defmodule MyModule do
        raise ArgumentError, "Error"
      end
      """

      %{subject: subject, docs: %{docs: docs}} = ElixirSense.docs(buffer, 2, 11)

      assert subject == "ArgumentError"
      assert docs == "No documentation available"
    end

  end
end
