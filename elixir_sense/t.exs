socket = '/tmp/elixir-sense-1500874896440962000.sock'
{:ok, socket} = :gen_tcp.connect({:local, socket}, 0, [:binary, active: false, packet: 4])

code = """
defmodule MyModule do
  alias List, as: MyList
  List.flatten
  Interface.UserService
end
"""

scode = """
defmodule MyModule do
  import List
end
"""

request = %{
  "request_id" => 3,
  "auth_token" => nil,
  "request" => "definition",
  "payload" => %{
    "buffer" => code,
    "line" => 3,
    "column" => 6
  }
}

data = :erlang.term_to_binary(request)
:ok = :gen_tcp.send(socket, data)
{:ok, response} = :gen_tcp.recv(socket, 0)
:erlang.binary_to_term(response)
|> IO.inspect
