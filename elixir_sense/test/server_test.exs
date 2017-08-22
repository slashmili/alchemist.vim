defmodule TCPHelper do

  def send_request(socket, request) do
    data = :erlang.term_to_binary(request)
    send_and_recv(socket, data)
    |> :erlang.binary_to_term
    |> Map.get(:payload)
  end

  def send_and_recv(socket, data) do
    :ok = :gen_tcp.send(socket, data)
    {:ok, response} = :gen_tcp.recv(socket, 0, 1000)
    response
  end

end

defmodule ElixirSense.ServerTest do
  use ExUnit.Case

  alias ElixirSense.Server.ContextLoader
  import ExUnit.CaptureIO
  import TCPHelper

  setup_all do
    ["ok", "localhost", port, auth_token] = capture_io(fn ->
      ElixirSense.Server.start(["tcpip", "0", "dev"])
    end) |> String.split(":")
    port = port |> String.trim |> String.to_integer
    auth_token = auth_token|> String.trim
    {:ok, socket} = :gen_tcp.connect('localhost', port, [:binary, active: false, packet: 4])

    {:ok, socket: socket, auth_token: auth_token}
  end

  test "definition request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "definition",
      "payload" => %{
        "buffer" => "Enum.to_list",
        "line" => 1,
        "column" => 6
      }
    }
    assert send_request(socket, request) =~ "enum.ex:2576"
  end

  test "signature request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "signature",
      "payload" => %{
        "buffer" => "List.flatten(par, ",
        "line" => 1,
        "column" => 18
      }
    }
    assert send_request(socket, request).active_param == 1
  end

  test "quote request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "quote",
      "payload" => %{
        "code" => "var = 1",
      }
    }
    assert send_request(socket, request) == "{:=, [line: 1], [{:var, [line: 1], nil}, 1]}"
  end

  test "match request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "match",
      "payload" => %{
        "code" => "{var1, var2} = {1, 2}",
      }
    }
    assert send_request(socket, request) == "# Bindings\n\nvar1 = 1\n\nvar2 = 2"
  end

  test "expand request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "expand_full",
      "payload" => %{
        "buffer" => "",
        "selected_code" => "unless true, do: false",
        "line" => 1
      }
    }
    assert send_request(socket, request).expand_once == "if(true) do\n  nil\nelse\n  false\nend"
  end

  test "docs request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "docs",
      "payload" => %{
        "buffer" => "Enum.to_list",
        "line" => 1,
        "column" => 6
      }
    }
    assert send_request(socket, request).docs.docs =~ "> Enum.to_list"
  end

  test "suggestions request", %{socket: socket, auth_token: auth_token} do
    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "suggestions",
      "payload" => %{
        "buffer" => "List.",
        "line" => 1,
        "column" => 6
      }
    }
    assert send_request(socket, request) |> Enum.at(0) == %{type: :hint, value: "List."}
  end

  test "set_context request", %{socket: socket, auth_token: auth_token} do
    {_, _, _, env, cwd, _} = ContextLoader.get_state()

    assert env == "dev"

    request = %{
      "request_id" => 1,
      "auth_token" => auth_token,
      "request" => "set_context",
      "payload" => %{
        "env" => "test",
        "cwd" => cwd
      }
    }
    send_request(socket, request)

    {_, _, _, env, _, _} = ContextLoader.get_state()
    assert env == "test"
  end

  test "unauthorized request", %{socket: socket} do
    request = %{
      "request_id" => 1,
      "auth_token" => "not the right token",
      "request" => "match",
      "payload" => %{
        "code" => "{var1, var2} = {1, 2}",
      }
    }
    data = :erlang.term_to_binary(request)
    response = send_and_recv(socket, data) |> :erlang.binary_to_term

    assert response.payload == nil
    assert response.error == "unauthorized"
  end

end

defmodule ElixirSense.ServerUnixSocketTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import TCPHelper

  setup_all do
    ["ok", "localhost", file] = capture_io(fn ->
       ElixirSense.Server.start(["unix", "0", "dev"])
     end) |> String.split(":")
    file = file |> String.trim |> String.to_charlist
    {:ok, socket} = :gen_tcp.connect({:local, file}, 0, [:binary, active: false, packet: 4])

    {:ok, socket: socket}
  end

  test "suggestions request", %{socket: socket} do
    request = %{
      "request_id" => 1,
      "auth_token" => nil,
      "request" => "suggestions",
      "payload" => %{
        "buffer" => "List.",
        "line" => 1,
        "column" => 6
      }
    }
    assert send_request(socket, request) |> Enum.at(0) == %{type: :hint, value: "List."}
  end

end
