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
      children = [
        RecruitingDemo.AuditLog,
        {Task.Supervisor, name: RecruitingDemo.TaskSupervisor},
        {RecruitingDemo.RateLimit, clean_period: :timer.minutes(1)}
      ]

      Supervisor.init(children, strategy: :one_for_one)
    else
      :ignore
    end
  end
end
