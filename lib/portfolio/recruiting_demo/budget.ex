defmodule Portfolio.RecruitingDemo.Budget do
  @moduledoc """
  Spending limits of the public demo:

    * a token budget per application, read from its own journal;
    * a global cost cap per day (USD), kept in memory. Once reached, agents
      fall back to the simulated models until the next day.
  """
  use Agent

  require Ash.Query

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Resources.AuditEvent

  def start_link(_opts), do: Agent.start_link(fn -> {Date.utc_today(), 0.0} end, name: __MODULE__)

  @doc "Records the cost of one model call."
  def spend(cost) when is_number(cost) do
    Agent.update(__MODULE__, fn {day, spent} ->
      today = Date.utc_today()
      if day == today, do: {day, spent + cost}, else: {today, cost}
    end)
  end

  def spend(_cost), do: :ok

  @doc "Cost spent today, in USD."
  def spent_today do
    Agent.get(__MODULE__, fn {day, spent} -> if day == Date.utc_today(), do: spent, else: 0.0 end)
  end

  @doc "Whether the daily cost cap is reached."
  def daily_cap_reached?, do: spent_today() >= daily_cap()

  @doc "Tokens already used by an application's agents."
  def tokens_used(application_id) do
    AuditEvent
    |> Ash.Query.filter(application_id == ^application_id and type == "agent_output")
    |> Ash.read!(authorize?: false)
    |> Enum.reduce(0, fn %{payload: %{"usage" => usage}}, acc ->
      acc + (usage["input_tokens"] || 0) + (usage["output_tokens"] || 0)
    end)
  end

  @doc "`:ok`, or `{:error, :token_budget_exceeded}` once an application used its budget."
  def check_application(application_id) do
    if tokens_used(application_id) < tokens_per_application(),
      do: :ok,
      else: {:error, :token_budget_exceeded}
  end

  defp config, do: Keyword.get(RecruitingDemo.config(), :budget, [])
  def tokens_per_application, do: Keyword.get(config(), :tokens_per_application, 80_000)
  def daily_cap, do: Keyword.get(config(), :daily_cost_usd, 2.0)
end
