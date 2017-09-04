defmodule SelfDestructTimer do

  #doc "Self destruct after how many seconds?"
  @timeout 600

  def start_link(_) do
    {:ok, pid} = Agent.start_link(&now/0, name: __MODULE__ )
    case Code.ensure_loaded(DateTime) do
      {:error, _} -> :noop
      _ -> schedule_tick()
    end
    {:ok, pid}
  end

  @doc "Time is counting down. Tick tack, tick tack. Self-destruct if we reached the timeout."
  def tick do
    case idle_expired() do
      true  -> destroy()
      false -> :ok = schedule_tick()
    end
  end

  @doc "Register activity, resetting the self-destruct timer"
  def reset, do: Agent.update(__MODULE__, fn _ -> now() end)

  #doc "Self destruct after how many seconds?"

  #doc "Current time as unix timestamp"
  defp now, do: DateTime.utc_now |> DateTime.to_unix

  #doc "Unix timestamp of last request"
  defp last_request, do: Agent.get(__MODULE__, &(&1))

  #doc "How many secons we have been idling"
  defp idle_time, do: now() - last_request()

  #doc "Have we reached self-destruct time yet?"
  defp idle_expired do
    idle_time() >= @timeout
  end

  #doc "Boom!"
  defp destroy, do: System.halt(42)

  defp schedule_tick do
    :timer.apply_after(60_000, __MODULE__, :tick, [])
    :ok
  end
end
