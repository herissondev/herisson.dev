defmodule Portfolio.RecruitingDemo.Pipeline.ScreeningReactor do
  @moduledoc """
  Triage, then (if the CV goes on) research and matching. Ends on a waiting
  state: no process stays blocked until the visitor clicks.
  """
  use Reactor

  alias Portfolio.RecruitingDemo.Agents.Triage
  alias Portfolio.RecruitingDemo.Pipeline.{AgentStep, InputStep, Middleware, SystemStep}

  middlewares do
    middleware Middleware
  end

  input :application_id

  step :start_triage, {SystemStep, action: :start_triage} do
    argument :application_id, input(:application_id)
  end

  step :triage_input, {InputStep, agent: Triage} do
    argument :application_id, input(:application_id)
    wait_for :start_triage
  end

  step :triage, {AgentStep, agent: Triage} do
    argument :input, result(:triage_input)
    max_retries 0
  end

  step :route, {SystemStep, action: :route_after_triage} do
    argument :application_id, input(:application_id)
    wait_for :triage
  end

  # researching -> research and matching; rejected / manual_review -> stop here
  step :continue do
    argument :application, result(:route)

    run fn %{application: application}, context ->
      if application.state == :researching,
        do:
          Portfolio.RecruitingDemo.Pipeline.run_sub(
            Portfolio.RecruitingDemo.Pipeline.MatchingReactor,
            context
          ),
        else: {:ok, application}
    end
  end

  return :continue
end
