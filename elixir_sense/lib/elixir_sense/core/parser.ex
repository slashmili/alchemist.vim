defmodule ElixirSense.Core.Parser do
  @moduledoc """
  Core Parser
  """

  alias ElixirSense.Core.MetadataBuilder
  alias ElixirSense.Core.Metadata

  def parse_file(file, try_to_fix_parse_error, try_to_fix_line_not_found, cursor_line_number) do
    case File.read(file) do
      {:ok, source} ->
        parse_string(source, try_to_fix_parse_error, try_to_fix_line_not_found, cursor_line_number)
      error -> error
    end
  end

  def parse_string(source, try_to_fix_parse_error, try_to_fix_line_not_found, cursor_line_number) do
    case string_to_ast(source, try_to_fix_parse_error, cursor_line_number) do
      {:ok, ast} ->
        acc = MetadataBuilder.build(ast)
        if Map.has_key?(acc.lines_to_env, cursor_line_number) or !try_to_fix_line_not_found  do
          %Metadata{
            source: source,
            mods_funs_to_lines: acc.mods_funs_to_lines,
            lines_to_env: acc.lines_to_env
          }
        else
          # IO.puts :stderr, "LINE NOT FOUND"
          source
          |> fix_line_not_found(cursor_line_number)
          |> parse_string(false, false, cursor_line_number)
        end
      {:error, error} ->
        # IO.puts :stderr, "CAN'T FIX IT"
        # IO.inspect :stderr, error, []
        %Metadata{
          source: source,
          error: error
        }
    end
  end

  defp string_to_ast(source, try_to_fix_parse_error, cursor_line_number) do
    case Code.string_to_quoted(source) do
      {:ok, ast} ->
        {:ok, ast}
      error ->
        # IO.puts :stderr, "PARSE ERROR"
        # IO.inspect :stderr, error, []
        if try_to_fix_parse_error do
          source
          |> fix_parse_error(cursor_line_number, error)
          |> string_to_ast(false, cursor_line_number)
        else
          error
        end
    end
  end

  defp fix_parse_error(source, _cursor_line_number, {:error, {line, {"\"" <> <<_::bytes-size(1)>> <> "\" is missing terminator" <> _, _}, _}}) when is_integer(line) do
    source
    |> replace_line_with_marker(line)
  end

  defp fix_parse_error(source, _cursor_line_number, {:error, {_line, {_error_type, text}, _token}}) do
    [_, line] = Regex.run(Regex.recompile!(~r/line\s(\d+)/), text)
    line = line |> String.to_integer
    source
    |> replace_line_with_marker(line)
  end

  defp fix_parse_error(source, cursor_line_number, {:error, {line, "syntax" <> _, "'end'"}}) when is_integer(line) do
    source
    |> replace_line_with_marker(cursor_line_number)
  end

  defp fix_parse_error(source, _cursor_line_number, {:error, {line, "syntax" <> _, _token}}) when is_integer(line) do
    source
    |> replace_line_with_marker(line)
  end

  defp fix_parse_error(_, nil, error) do
    error
  end

  defp fix_parse_error(source, cursor_line_number, _error) do
    source
    |> replace_line_with_marker(cursor_line_number)
  end

  defp fix_line_not_found(source, line_number) do
    source |> replace_line_with_marker(line_number)
  end

  defp replace_line_with_marker(source, line) do
    # IO.puts :stderr, "REPLACING LINE: #{line}"
    source
    |> String.split(["\n", "\r\n"])
    |> List.replace_at(line - 1, "(__atom_elixir_marker_#{line}__())")
    |> Enum.join("\n")
  end

end
