defmodule Alchemist.API.Ping do

  @moduledoc false

  def request(device) do
    process(device)
  end

  def process(device) do
    IO.puts device, "PONG"
    IO.puts device, "END-OF-PING"
  end
end
