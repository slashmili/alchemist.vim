Code.require_file "../helpers/process_commands.exs", __DIR__

defmodule Alchemist.Server.Socket do

  alias Alchemist.Helpers.ProcessCommands

  def start(opts) do
    import Supervisor.Spec

    env = Keyword.get(opts, :env)
    port = Keyword.get(opts, :port, 0)

    children = [
      supervisor(Task.Supervisor, [[name: Alchemist.Server.Socket.TaskSupervisor]]),
      worker(Task, [__MODULE__, :accept, [env, port]])
    ]

    opts = [strategy: :one_for_one, name: KVServer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def accept(env, port) do
    {:ok, socket} = :gen_tcp.listen(port,
                    [:binary, packet: :line, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    IO.puts "ok|localhost:#{port}"
    loop_acceptor(socket, env)
  end

  defp loop_acceptor(socket, env) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Alchemist.Server.Socket.TaskSupervisor, fn -> serve(client, env) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, env)
  end

  defp serve(socket, env) do
    {:ok, io_string} = StringIO.open("")
    socket
    |> read_line
    |> String.strip
    |> ProcessCommands.process(env, io_string)

    {:ok, {_, output}} = StringIO.close(io_string)
    write_line(output, socket)

    serve(socket, env)
  end

  defp read_line(socket) do
    #TODO: handle {:error, :closed}
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
