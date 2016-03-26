Code.require_file "../helpers/complete.exs", __DIR__

defmodule Alchemist.API.Comp do

  @moduledoc false

  alias Alchemist.Helpers.Complete

  def request(args, device) do
    args
    |> normalize
    |> process(device)
  end

  def process([nil, _, imports, _], device) do
    Complete.run('', imports) ++ Complete.run('')
    |> print(device)
  end

  def process([hint, _context, imports, aliases], device) do
    Application.put_env(:"alchemist.el", :aliases, aliases)

    Complete.run(hint, imports) ++ Complete.run(hint)
    |> print(device)
  end

  defp normalize(request) do
    {{hint, [ context: context,
              imports: imports,
              aliases: aliases ]}, _} =  Code.eval_string(request)
    [hint, context, imports, aliases]
  end

  defp print(result, device) do
    result
    |> Enum.uniq
    |> Enum.map(&IO.puts(device, &1))

    IO.puts device, "END-OF-COMP"
  end
end
