defmodule Portfolio.RecruitingDemo.Pipeline.ForcedCallReactor do
  @moduledoc """
  One agent turn whose model is replaced by `Agents.Forced`: it builds the
  agent's real input, then asks for `send_email`. Used by the "force a
  forbidden call" button to show the policy refusing it.
  """
  use Reactor

  alias Portfolio.RecruitingDemo.Pipeline.{AgentStep, InputStep, Middleware}

  middlewares do
    middleware Middleware
  end

  input :application_id
  input :agent

  step :forced_input, {InputStep, []} do
    argument :application_id, input(:application_id)
    argument :agent, input(:agent)
  end

  step :forced_call, {AgentStep, []} do
    argument :input, result(:forced_input)
    argument :agent, input(:agent)
    max_retries 0
  end

  return :forced_call
end
