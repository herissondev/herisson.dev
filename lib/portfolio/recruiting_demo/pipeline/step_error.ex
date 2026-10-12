defmodule Portfolio.RecruitingDemo.Pipeline.StepError do
  @moduledoc "An agent that kept failing after all its attempts."
  defexception [:agent, :reason, :attempts]

  @impl true
  def message(%{agent: agent, reason: reason, attempts: attempts}),
    do: "#{agent} failed after #{attempts} attempt(s): #{inspect(reason)}"
end
