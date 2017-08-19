defmodule ElixirSense.Server.ContextLoader do
  @moduledoc """
  Server Context Loader
  """
  use GenServer

  @minimal_reload_time 2000

  def start_link(env) do
    GenServer.start_link(__MODULE__, env, [name: __MODULE__])
  end

  def init(env) do
    {:ok, {all_loaded(), [], [], env, Path.expand("."), 0}}
  end

  def set_context(env, cwd) do
    GenServer.call(__MODULE__, {:set_context, {env, cwd}})
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  def handle_call(:reload, _from, {loaded, paths, apps, env, cwd, last_load_time}) do
    time = :erlang.system_time(:milli_seconds)
    reload = time - last_load_time > @minimal_reload_time

    {new_paths, new_apps} =
      if reload do
        purge_modules(loaded)
        purge_paths(paths)
        purge_apps(apps)
        {load_paths("test", cwd), load_apps("test", cwd)}
        {load_paths(env, cwd), load_apps(env, cwd)}
      else
        {paths, apps}
      end

    {:reply, :ok, {loaded, new_paths, new_apps, env, cwd, time}}
  end

  def handle_call({:set_context, {env, cwd}}, _from, {loaded, paths, apps, _env, _cwd, last_load_time}) do
    {:reply, {env, cwd}, {loaded, paths, apps, env, cwd, last_load_time}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp preload_modules(modules) do
    modules |> Enum.each(fn mod ->
      {:module, _} = Code.ensure_loaded(mod)
    end)
  end

  defp all_loaded do
    preload_modules([Inspect, :base64, :crypto])
    for {m, _} <- :code.all_loaded, do: m
  end

  defp load_paths(env, cwd) do
    for path <- Path.wildcard(Path.join(cwd, "_build/#{env}/lib/*/ebin")) do
      Code.prepend_path(path)
      path
    end
  end

  defp load_apps(env, cwd) do
    for path <- Path.wildcard(Path.join(cwd, "_build/#{env}/lib/*/ebin/*.app")) do
      app = path |> Path.basename() |> Path.rootname() |> String.to_atom
      Application.load(app)
      app
    end
  end

  defp purge_modules(loaded) do
    for m <- (all_loaded() -- loaded) do
      :code.delete(m)
      :code.purge(m)
    end
  end

  defp purge_paths(paths) do
    for p <- paths, do: Code.delete_path(p)
  end

  defp purge_apps(apps) do
    for a <- apps, do: Application.unload(a)
  end

end
