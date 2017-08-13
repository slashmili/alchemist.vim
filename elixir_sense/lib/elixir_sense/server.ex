defmodule ElixirSense.Server do
  @moduledoc """
  Server entry point and coordinator
  """

  alias ElixirSense.Server.TCPServer

  def start(args) do
    [socket_type, port, env] = validate_args(args)
    IO.puts(:stderr, "Initializing ElixirSense server for environment \"#{env}\" (Elixir version #{System.version})")
    IO.puts(:stderr, "Working directory is \"#{Path.expand(".")}\"")
    TCPServer.start([socket_type: socket_type, port: port, env: env])
    loop()
  end

  defp validate_args(["unix", _port, env] = args) do
    {version, _} = :otp_release |> :erlang.system_info() |> :string.to_integer()
    if version < 19 do
      IO.puts(:stderr, "Warning: Erlang version < 19. Cannot use Unix domain sockets. Using tcp/ip instead.")
      ["tcpip", "0", env]
    else
      args
    end
  end
  defp validate_args(args) do
    args
  end

  defp loop do
    case IO.gets("") do
      :eof ->
        IO.puts(:stderr, "Stopping ElixirSense server")
      _  ->
        loop()
    end
  end

end
