defmodule ElixirSense.Core.IntrospectionTest do

  use ExUnit.Case

  import ElixirSense.Core.Introspection

  test "get_callbacks_with_docs for erlang behaviours" do
    assert get_callbacks_with_docs(:supervisor) == [%{
      name: :init,
      arity: 1,
      callback: """
      @callback init(args :: term) ::
        {:ok, {supFlags :: sup_flags, [childSpec :: child_spec]}} |
        :ignore
      """,
      signature: "init(args)",
      doc: nil
    }]
  end

  test "get_callbacks_with_docs for Elixir behaviours with no docs defined" do
    assert get_callbacks_with_docs(Exception) == [
      %{name: :exception, arity: 1, callback: "@callback exception(term) :: t\n",   signature: "exception(term)", doc: nil},
      %{name: :message,   arity: 1, callback: "@callback message(t) :: String.t\n", signature: "message(t)",      doc: nil}
    ]
  end

  test "get_callbacks_with_docs for Elixir behaviours with docs defined" do
    info = get_callbacks_with_docs(GenServer) |> Enum.at(0)

    assert info.name      == :code_change
    assert info.arity     == 3
    assert info.callback  == """
    @callback code_change(old_vsn, state :: term, extra :: term) ::
      {:ok, new_state :: term} |
      {:error, reason :: term} when old_vsn: term | {:down, term}
    """
    assert info.doc       =~ "Invoked to change the state of the `GenServer`"
    assert info.signature == "code_change(old_vsn, state, extra)"
  end

  test "format_spec_ast with one return option does not aplit the returns" do
    type_ast = get_type_ast(GenServer, :debug)

    assert format_spec_ast(type_ast) == """
    debug :: [:trace | :log | :statistics | {:log_to_file, Path.t}]
    """
  end

  test "format_spec_ast with more than one return option aplits the returns" do
    type_ast = get_type_ast(GenServer, :on_start)

    assert format_spec_ast(type_ast) == """
    on_start ::
      {:ok, pid} |
      :ignore |
      {:error, {:already_started, pid} | term}
    """
  end

  test "format_spec_ast for callback" do
    ast = get_callback_ast(GenServer, :code_change, 3)
    assert format_spec_ast(ast) == """
    code_change(old_vsn, state :: term, extra :: term) ::
      {:ok, new_state :: term} |
      {:error, reason :: term} when old_vsn: term | {:down, term}
    """
  end

  test "get_returns_from_callback" do
    returns = get_returns_from_callback(GenServer, :code_change, 3)
    assert returns == [
      %{description: "{:ok, new_state}", snippet: "{:ok, \"${1:new_state}$\"}", spec: "{:ok, new_state :: term} when old_vsn: term | {:down, term}"},
      %{description: "{:error, reason}", snippet: "{:error, \"${1:reason}$\"}", spec: "{:error, reason :: term} when old_vsn: term | {:down, term}"}
    ]
  end

  test "get_returns_from_callback (all types in 'when')" do
    returns = get_returns_from_callback(:gen_server, :handle_call, 3)
    assert returns == [
      %{description: "{:reply, reply, new_state}", snippet: "{:reply, \"${1:reply}$\", \"${2:new_state}$\"}", spec: "{:reply, reply, new_state} when reply: term, new_state: term, reason: term"},
      %{description: "{:reply, reply, new_state, timeout | :hibernate}", snippet: "{:reply, \"${1:reply}$\", \"${2:new_state}$\", \"${3:timeout | :hibernate}$\"}", spec: "{:reply, reply, new_state, timeout | :hibernate} when reply: term, new_state: term, reason: term"},
      %{description: "{:noreply, new_state}", snippet: "{:noreply, \"${1:new_state}$\"}", spec: "{:noreply, new_state} when reply: term, new_state: term, reason: term"},
      %{description: "{:noreply, new_state, timeout | :hibernate}", snippet: "{:noreply, \"${1:new_state}$\", \"${2:timeout | :hibernate}$\"}", spec: "{:noreply, new_state, timeout | :hibernate} when reply: term, new_state: term, reason: term"},
      %{description: "{:stop, reason, reply, new_state}", snippet: "{:stop, \"${1:reason}$\", \"${2:reply}$\", \"${3:new_state}$\"}", spec: "{:stop, reason, reply, new_state} when reply: term, new_state: term, reason: term"},
      %{description: "{:stop, reason, new_state}", snippet: "{:stop, \"${1:reason}$\", \"${2:new_state}$\"}", spec: "{:stop, reason, new_state} when reply: term, new_state: term, reason: term"}
    ]
  end

  test "get_returns_from_callback (erlang specs)" do
    returns = get_returns_from_callback(:gen_fsm, :handle_event, 3)
    assert returns == [
      %{description: "{:next_state, nextStateName, newStateData}", snippet: "{:next_state, \"${1:nextStateName}$\", \"${2:newStateData}$\"}", spec: "{:next_state, nextStateName :: atom, newStateData :: term}"},
      %{description: "{:next_state, nextStateName, newStateData, timeout | :hibernate}", snippet: "{:next_state, \"${1:nextStateName}$\", \"${2:newStateData}$\", \"${3:timeout | :hibernate}$\"}", spec: "{:next_state, nextStateName :: atom, newStateData :: term, timeout | :hibernate}"},
      %{description: "{:stop, reason, newStateData}", snippet: "{:stop, \"${1:reason}$\", \"${2:newStateData}$\"}", spec: "{:stop, reason :: term, newStateData :: term}"}
    ]
  end

  defp get_type_ast(module, type) do
    {_kind, type} =
      Kernel.Typespec.beam_types(module)
      |> Enum.find(fn {_, {name, _, _}} -> name == type end)
    Kernel.Typespec.type_to_ast(type)
  end

end
