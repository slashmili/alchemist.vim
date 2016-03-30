Code.require_file "../helpers/module_info.exs", __DIR__
Code.require_file "../helpers/capture_io.exs", __DIR__

defmodule Alchemist.API.Docl do

  @moduledoc false

  import IEx.Helpers, warn: false

  alias Alchemist.Helpers.ModuleInfo
  alias Alchemist.Helpers.CaptureIO

  def request(args, device) do
    args
    |> normalize
    |> process(device)

    IO.puts device, "END, func_puts-OF-DOCL"
  end

  def process([expr, modules, aliases], device) do
    search(expr, modules, aliases, device)
  end

  def search(nil, _device), do: true
  def search(expr, device) do
    try do
      help = CaptureIO.capture_io(fn ->
        Code.eval_string("h(#{expr})", [], __ENV__)
      end)
      IO.write device, help
    rescue
      _e -> nil
    end
  end

  def search(expr, modules, [], device) do
    expr = to_string expr
    unless function?(expr) do
      search(expr, device)
    else
      search_with_context(modules, expr, device)
    end
  end

  def search(expr, modules, aliases, device) do
    unless function?(expr) do
      String.split(expr, ".")
      |> ModuleInfo.expand_alias(aliases)
      |> search(device)
    else
      search_with_context(modules, expr, device)
    end
  end

  defp search_with_context(modules, expr, device) do
    modules ++ [Kernel, Kernel.SpecialForms]
    |> build_search(expr)
    |> search(device)
  end

  defp build_search(modules, search) do
    function = Regex.replace(~r/\/[0-9]$/, search, "")
    function = String.to_atom(function)
    for module <- modules,
    ModuleInfo.docs?(module, function) do
      "#{module}.#{search}"
    end |> List.first
  end

  defp function?(expr) do
    Regex.match?(~r/^[a-z_]/, expr)
  end

  defp normalize(request) do
    {{expr, [ context: _,
              imports: imports,
              aliases: aliases]}, _} = Code.eval_string(request)
    [expr, imports, aliases]
  end
end
