Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/api/ping.exs", __DIR__

defmodule Alchemist.API.PingTest do

  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Alchemist.API.Ping

  test "PING request" do
    assert capture_io(fn ->
      Ping.process(Process.group_leader)
    end) =~ """
    PONG
    END-OF-PING
    """
  end
end
