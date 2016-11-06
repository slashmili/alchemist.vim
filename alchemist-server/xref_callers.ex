# taken from https://github.com/elixir-lang/elixir/blob/master/lib/mix/lib/mix/tasks/xref.ex
# as of https://github.com/elixir-lang/elixir/commit/690c2c40c948564f7db5fccfd66246ed78c6fe8d
defmodule Mix.Tasks.Xref.Callers do
  use Mix.Task

  alias Mix.Tasks.Compile.Elixir, as: E
  import Mix.Compilers.Elixir, only: [read_manifest: 2, source: 1, source: 2]

  @shortdoc "Performs cross reference checks"
  @recursive true

  @moduledoc """
  Performs cross reference checks between modules.

  ## Xref modes

  The `xref` task expects a mode as first argument:

      mix xref MODE

  All available modes are discussed below.

  ### callers CALLEE

  Prints all callers of the given `CALLEE`, which can be one of: `Module`,
  `Module.function`, or `Module.function/arity`. Examples:

      mix xref callers MyMod
      mix xref callers MyMod.fun
      mix xref callers MyMod.fun/3

  ## Shared options

  Those options are shared across all modes:

    * `--no-compile` - does not compile even if files require compilation

    * `--no-deps-check` - does not check dependencies

    * `--no-archives-check` - does not check archives

    * `--no-elixir-version-check` - does not check the Elixir version from mix.exs

  ## Configuration

  All configuration for Xref should be placed under the key `:xref`.

    * `:exclude` - a list of modules and `{module, function, arity}` tuples to ignore when checking
      cross references. For example: `[MissingModule, {MissingModule2, :missing_func, 2}]`

  """

  @switches [compile: :boolean, deps_check: :boolean, archives_check: :boolean,
             elixir_version_check: :boolean, exclude: :keep, format: :string,
             source: :string, sink: :string]

  @doc """
  Runs this task.
  """
  @spec run(OptionParser.argv) :: :ok | :error
  def run(args) do
    {opts, args} =
      OptionParser.parse!(args, strict: @switches)

    Mix.Task.run("loadpaths")

    if Keyword.get(opts, :compile, true) do
      Mix.Task.run("compile")
    end

    case args do
      ["callers", callee] ->
        callers(callee)
      _ ->
        Mix.raise "xref doesn't support this command, see \"mix help xref\" for more information"
    end
  end

  ## Modes

  def callers(callee) do
    callee
    |> filter_for_callee()
    |> do_callers()
  end

  ## Callers

  defp do_callers(filter) do
    each_source_entries(&source_calls_for_filter(&1, filter), &print_calls/2)
  end

  defp source_calls_for_filter(source, filter) do
    runtime_dispatches = source(source, :runtime_dispatches)
    compile_dispatches = source(source, :compile_dispatches)
    dispatches = runtime_dispatches ++ compile_dispatches

    calls =
      for {module, func_arity_lines} <- dispatches,
          {{func, arity}, lines} <- func_arity_lines,
          filter.({module, func, arity}),
          do: {module, func, arity, lines}

    Enum.reduce calls, %{}, fn {module, func, arity, lines}, merged_calls ->
      lines = MapSet.new(lines)
      Map.update(merged_calls, {module, func, arity}, lines, &MapSet.union(&1, lines))
    end
  end

  ## Print callers

  defp print_calls(file, calls) do
    calls
    |> Enum.sort()
    |> Enum.map(&format_call(file, &1))
    #|> IO.puts
    #|> Enum.each(&IO.write(format_call(file, &1)))
  end

  defp format_call(file, {{module, func, arity}, lines}) do
    for line <- Enum.sort(lines),
      do: [file, ":", to_string(line), ": ", Exception.format_mfa(module, func, arity), ?\n]
  end

  ## "Callers" helpers

  defp filter_for_callee(callee) do
    mfa_list =
      case Code.string_to_quoted(callee) do
        {:ok, quoted_callee} ->
          quoted_to_mfa_list(quoted_callee)
        {:error, _} -> raise_invalid_callee(callee)
      end

    mfa_list_length = length(mfa_list)

    fn {module, function, arity} ->
      mfa_list == Enum.take([module, function, arity], mfa_list_length)
    end
  end

  defp quoted_to_mfa_list(quoted) do
    quoted
    |> do_quoted_to_mfa_list()
    |> Enum.reverse()
  end

  defp do_quoted_to_mfa_list({:__aliases__, _, aliases}) do
    [Module.concat(aliases)]
  end

  defp do_quoted_to_mfa_list({{:., _, [module, func]}, _, []}) when is_atom(func) do
    [func | do_quoted_to_mfa_list(module)]
  end

  defp do_quoted_to_mfa_list({:/, _, [dispatch, arity]}) when is_integer(arity) do
    [arity | do_quoted_to_mfa_list(dispatch)]
  end

  defp do_quoted_to_mfa_list(other) do
    other
    |> Macro.to_string()
    |> raise_invalid_callee()
  end

  defp raise_invalid_callee(callee) do
    message =
      "xref callers CALLEE expects Module, Module.function, or Module.function/arity, got: " <>
      callee

    Mix.raise message
  end

  ## Helpers

  defp each_source_entries(entries_fun, pair_fun) do
    for manifest <- E.manifests(),
        source(source: file) = source <- read_manifest(manifest, ""),
        entries = entries_fun.(source),
        entries != [] and entries != %{},
        do: pair_fun.(file, entries)
  end
end
