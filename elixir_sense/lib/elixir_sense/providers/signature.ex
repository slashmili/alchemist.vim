defmodule ElixirSense.Providers.Signature do

  @moduledoc """
  Provider responsible for introspection information about function signatures.
  """

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.Metadata

  @type signature :: %{name: String.t, params: [String.t]}
  @type signature_info :: %{active_param: pos_integer, signatures: [signature]} | :none

  @doc """
  Returns the signature info from the function defined in the prefix, if any.
  """
  @spec find(String.t, [module], [{module, module}], module, map) :: signature_info
  def find(prefix, imports, aliases, module, metadata) do
    case Source.which_func(prefix) do
      %{candidate: {mod, fun}, npar: npar, pipe_before: pipe_before} ->
        {mod, fun} = Introspection.actual_mod_fun({mod, fun}, imports, aliases, module)
        signatures = find_signatures({mod, fun}, metadata)
        %{active_param: npar, pipe_before: pipe_before, signatures: signatures}
      _ ->
        :none
    end
  end

  defp find_signatures({mod, fun}, metadata) do
    docs = Code.get_docs(mod, :docs)
    signatures = case Metadata.get_function_signatures(metadata, mod, fun, docs) do
      [] -> Introspection.get_signatures(mod, fun, docs)
      signatures -> signatures
    end
    signatures |> Enum.uniq_by(fn sig -> sig.params end)
  end

end
