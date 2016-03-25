Code.require_file "../helpers/module_info.exs", __DIR__
Code.require_file "../helpers/complete.exs", __DIR__
Code.require_file "../helpers/capture_io.exs", __DIR__

defmodule Alchemist.API.Info do

  @moduledoc false

  import IEx.Helpers, warn: false

  alias Alchemist.Helpers.ModuleInfo
  alias Alchemist.Helpers.Complete
  alias Alchemist.Helpers.CaptureIO

  def request(args, device) do
    args
    |> normalize
    |> process(device)
  end

  def process(:modules, device) do
    modules = ModuleInfo.all_applications_modules
    |> Enum.uniq
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&ModuleInfo.moduledoc?/1)

    functions = Complete.run('')

    modules ++ functions
    |> Enum.uniq
    |> Enum.map(&IO.puts(device, &1))

    IO.puts device, "END-OF-INFO"
  end

  def process(:mixtasks, device) do
    # append things like hex or phoenix archives to the load_path
    Mix.Local.append_archives

    :code.get_path
    |> Mix.Task.load_tasks
    |> Enum.map(&Mix.Task.task_name/1)
    |> Enum.sort
    |> Enum.map(&IO.puts(device, &1))

    IO.puts device, "END-OF-INFO"
  end

  def process({:info, arg}, device) do
    try do
      info = CaptureIO.capture_io(fn ->
        Code.eval_string("i(#{arg})", [], __ENV__)
      end)
      IO.write device, info
    rescue
      _e -> nil
    end

    IO.puts device, "END-OF-INFO"
  end

  def process({:types, arg}, device) do
    try do
      type = CaptureIO.capture_io(fn ->
        Code.eval_string("t(#{arg})", [], __ENV__)
      end)

      IO.write device, type
    rescue
      _e -> nil
    end

    IO.puts device, "END-OF-INFO"
  end

  def process(nil, device) do
   IO.puts device, "END-OF-INFO"
  end

  def normalize(request) do
    try do
      Code.eval_string(request)
    rescue
      _e -> nil
    else
      {{_, type }, _}     -> type
      {{_, type, arg}, _} ->
        if Version.match?(System.version, ">=1.2.0-rc") do
          {type, arg}
        else
          nil
        end
    end
  end
end
