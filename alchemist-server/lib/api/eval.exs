defmodule Alchemist.API.Eval do

  @moduledoc false

  def request(args, device) do
    args
    |> normalize
    |> process(device)

    IO.puts device, "END-OF-EVAL"
  end

  def process({:eval, file}, device) do
    try do
      eval = File.read!("#{file}")
              |> Code.eval_string
              |> Tuple.to_list
              |> List.first

      IO.inspect device, eval, []
    rescue
      e -> IO.inspect device, e, []
    end
  end

  def process({:quote, file}, device) do
    try do
      quot = File.read!("#{file}")
      |> Code.string_to_quoted
      |> Tuple.to_list
      |> List.last

      IO.inspect device, quot, []
    rescue
      e -> IO.inspect device, e, []
    end
  end

  def process({:expand, file}, device) do
    try do
      {_, expr} = File.read!("#{file}")
      |> Code.string_to_quoted
      res = Macro.expand(expr, __ENV__)
      IO.puts device, Macro.to_string(res)
    rescue
      e -> IO.inspect device, e, []
    end
  end

  def process({:expand_once, file}, device) do
    try do
      {_, expr} = File.read!("#{file}")
      |> Code.string_to_quoted
      res = Macro.expand_once(expr, __ENV__)
      IO.puts device, Macro.to_string(res)
    rescue
      e -> IO.inspect e
    end
  end

  def normalize(request) do
    {expr , _} = Code.eval_string(request)
    expr
  end
end
