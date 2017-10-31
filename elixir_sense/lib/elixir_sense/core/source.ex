defmodule ElixirSense.Core.Source do
  @moduledoc """
  Source parsing
  """

  @empty_graphemes [" ", "\n", "\r\n"]
  @stop_graphemes ~w/{ } ( ) [ ] < > + - * & ^ , ; ~ % = " ' \\ \/ $ ! ?`#/ ++ @empty_graphemes

  def prefix(code, line, col) do
    line = code |> String.split("\n") |> Enum.at(line - 1)
    line_str = line |> String.slice(0, col - 1)
    case Regex.run(Regex.recompile!(~r/[\w0-9\._!\?\:@]+$/), line_str) do
      nil -> ""
      [prefix] -> prefix
    end
  end

  def text_before(code, line, col) do
    pos = find_position(code, line, col, {0, 1, 1})
    {text, _rest} = String.split_at(code, pos)
    text
  end

  def subject(code, line, col) do
    case walk_text(code, &find_subject/5, %{line: line, col: col, pos_found: false, candidate: []}) do
      %{candidate: []} ->
        nil
      %{candidate: candidate} ->
        candidate |> Enum.reverse |> Enum.join
    end
  end

  defp find_subject(grapheme, rest, line, col, %{pos_found: false, line: line, col: col} = acc) do
    find_subject(grapheme, rest, line, col, %{acc | pos_found: true})
  end
  defp find_subject("." = grapheme, rest, _line, _col, %{pos_found: false} = acc) do
    {rest, %{acc | candidate: [grapheme|acc.candidate]}}
  end
  defp find_subject(".", _rest, _line, _col, %{pos_found: true} = acc) do
    {"", acc}
  end
  defp find_subject(grapheme, rest, _line, _col, %{candidate: [_|_]} = acc) when grapheme in ["!", "?"] do
    {rest, %{acc | candidate: [grapheme|acc.candidate]}}
  end
  defp find_subject(grapheme, rest, _line, _col, %{candidate: ["."|_]} = acc) when grapheme in @stop_graphemes do
    {rest, acc}
  end
  defp find_subject(grapheme, rest, _line, _col, %{pos_found: false} = acc) when grapheme in @stop_graphemes do
    {rest, %{acc | candidate: []}}
  end
  defp find_subject(grapheme, _rest, _line, _col, %{pos_found: true} = acc) when grapheme in @stop_graphemes do
    {"", acc}
  end
  defp find_subject(grapheme, rest, _line, _col, acc) do
    {rest, %{acc | candidate: [grapheme|acc.candidate]}}
  end

  defp walk_text(text, func, acc) do
    do_walk_text(text, func, 1, 1, acc)
  end

  defp do_walk_text(text, func, line, col, acc) do
    case String.next_grapheme(text) do
      nil ->
        acc
      {grapheme, rest} ->
        {new_rest, new_acc} = func.(grapheme, rest, line, col, acc)
        {new_line, new_col} =
          if grapheme in ["\n", "\r\n"] do
            {line + 1, 1}
          else
            {line, col + 1}
          end

        do_walk_text(new_rest, func, new_line, new_col, new_acc)
    end
  end

  defp find_position(_text, line, col, {pos, line, col}) do
    pos
  end

  defp find_position(text, line, col, {pos, current_line, current_col}) do
    case String.next_grapheme(text) do
      {grapheme, rest} ->
        {new_pos, new_line, new_col} =
          if grapheme in ["\n", "\r\n"] do
            {pos + 1, current_line + 1, 1}
          else
            {pos + 1, current_line, current_col + 1}
          end
          find_position(rest, line, col, {new_pos, new_line, new_col})
      nil ->
        pos
    end
  end

  def which_func(prefix) do
    tokens =
      case prefix |> String.to_charlist |> :elixir_tokenizer.tokenize(1, []) do
        {:ok, _, _, tokens} ->
          tokens |> Enum.reverse
        {:error, {_line, _error_prefix, _token}, _rest, sofar} ->
          # DEBUG
          # IO.puts :stderr, :elixir_utils.characters_to_binary(error_prefix)
          # IO.inspect(:stderr, {:sofar, sofar}, [])
          # IO.inspect(:stderr, {:rest, rest}, [])
          sofar
      end
    pattern = %{npar: 0, count: 0, count2: 0, candidate: [], pos: nil, pipe_before: false}
    result = scan(tokens, pattern)
    %{candidate: candidate, npar: npar, pipe_before: pipe_before, pos: pos} = result

    %{
      candidate: normalize_candidate(candidate),
      npar: normalize_npar(npar, pipe_before),
      pipe_before: pipe_before,
      pos: pos
    }
  end

  defp normalize_candidate(candidate) do
    case candidate do
      []          -> :none
      [func]      -> {nil, func}
      [mod, func] -> {mod, func}
      list        ->
        [func|mods] = Enum.reverse(list)
        {Module.concat(Enum.reverse(mods)), func}
    end
  end

  defp normalize_npar(npar, true), do: npar + 1
  defp normalize_npar(npar, _pipe_before), do: npar

  defp scan([{:",", _}|_], %{count: 1} = state), do: state
  defp scan([{:",", _}|tokens], %{count: 0, count2: 0} = state) do
    scan(tokens, %{state | npar: state.npar + 1, candidate: []})
  end
  defp scan([{:"(", _}|_], %{count: 1} = state), do: state
  defp scan([{:"(", _}|tokens], state) do
    scan(tokens, %{state | count: state.count + 1, candidate: []})
  end
  defp scan([{:")", _}|tokens], state) do
    scan(tokens, %{state | count: state.count - 1, candidate: []})
  end
  defp scan([{token, _}|tokens], %{count2: 0} = state) when token in [:"[", :"{"] do
    scan(tokens, %{state | npar: 0, count2: 0})
  end
  defp scan([{token, _}|tokens], state) when token in [:"[", :"{"] do
    scan(tokens, %{state | count2: state.count2 + 1})
  end
  defp scan([{token, _}|tokens], state) when token in [:"]", :"}"]do
    scan(tokens, %{state | count2: state.count2 - 1})
  end
  defp scan([{:paren_identifier, pos, value}|tokens], %{count: 1} = state) do
    scan(tokens, %{state | candidate: [value|state.candidate], pos: update_pos(pos, state.pos)})
  end
  defp scan([{:aliases, pos, [value]}|tokens], %{count: 1} = state) do
    updated_pos = update_pos(pos, state.pos)
    scan(tokens, %{state | candidate: [Module.concat([value])|state.candidate], pos: updated_pos})
  end
  defp scan([{:atom, pos, value}|tokens], %{count: 1} = state) do
    scan(tokens, %{state | candidate: [value|state.candidate], pos: update_pos(pos, state.pos)})
  end
  defp scan([{:fn, _}|tokens], %{count: 1} = state) do
    scan(tokens, %{state | npar: 0, count: 0})
  end
  defp scan([{:., _}|tokens], state), do: scan(tokens, state)
  defp scan([{:arrow_op, _, :|>}|_], %{count: 1} = state), do: pipe_before(state)
  defp scan([_|_], %{count: 1} = state), do: state
  defp scan([_token|tokens], state), do: scan(tokens, state)
  defp scan([], state), do: state

  defp update_pos({line, init_col, end_col}, nil) do
    {{line, init_col}, {line, end_col}}
  end
  defp update_pos({new_init_line, new_init_col, _}, {{_, _}, {end_line, end_col}}) do
    {{new_init_line, new_init_col}, {end_line, end_col}}
  end

  defp pipe_before(state) do
    %{state | pipe_before: true}
  end

end
