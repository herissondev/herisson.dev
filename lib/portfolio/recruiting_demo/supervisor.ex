defmodule Portfolio.RecruitingDemo.Supervisor do
  @moduledoc """
  Root of the demo's process tree. Starts nothing when the demo is disabled.
  """
  use Supervisor

  alias Portfolio.RecruitingDemo

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    if RecruitingDemo.enabled?() do
      create_tables()

      children = [
        RecruitingDemo.AuditLog,
        RecruitingDemo.Cleaner,
        RecruitingDemo.Budget,
        {Task.Supervisor, name: RecruitingDemo.TaskSupervisor},
        {RecruitingDemo.RateLimit, clean_period: :timer.minutes(1)}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    else
      :ignore
    end
  end

  # The ETS data layer creates a table on first write, and two concurrent
  # first writes (parallel research) can race; create them all up front.
  defp create_tables do
    for resource <- Ash.Domain.Info.resources(RecruitingDemo.Domain) do
      {:ok, _} = Ash.DataLayer.Ets.TableManager.start(resource, nil)
    end
  end
end
