defmodule Portfolio.RecruitingDemo.Cleaner do
  @moduledoc """
  Deletes a session's data once it has been idle for `:session_ttl_ms`.

  Purging works below the actions, straight on the ETS tables: the journal
  has no destroy action on purpose, and retention is a storage concern, not
  something an actor can do. A server restart also erases everything.
  """
  use GenServer

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Domain

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Records activity for a session."
  def touch(session_id), do: GenServer.cast(__MODULE__, {:touch, session_id, now()})

  @doc "Deletes every record of a session, in every demo table."
  def purge(session_id) do
    for resource <- Ash.Domain.Info.resources(Domain) do
      table = Ash.DataLayer.Ets.Info.table(resource)

      if :ets.whereis(table) != :undefined do
        :ets.select_delete(table, [{{:_, %{session_id: session_id}}, [], [true]}])
      end
    end

    :ok
  end

  @impl true
  def init(_opts) do
    schedule()
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:touch, session_id, at}, sessions),
    do: {:noreply, Map.put(sessions, session_id, at)}

  @impl true
  def handle_info(:sweep, sessions) do
    deadline = now() - ttl()
    {expired, active} = Map.split_with(sessions, fn {_session_id, at} -> at < deadline end)
    Enum.each(Map.keys(expired), &purge/1)
    schedule()
    {:noreply, active}
  end

  defp schedule, do: Process.send_after(self(), :sweep, sweep_every())
  defp ttl, do: Keyword.get(RecruitingDemo.config(), :session_ttl_ms, :timer.hours(2))
  defp sweep_every, do: Keyword.get(RecruitingDemo.config(), :sweep_every_ms, :timer.minutes(10))
  defp now, do: System.monotonic_time(:millisecond)
end
