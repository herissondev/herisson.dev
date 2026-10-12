defmodule Portfolio.RecruitingDemo.Pipeline.MatchingReactor do
  @moduledoc """
  Research by topic in parallel, then the Matcher with its bounded
  verification loop, then `awaiting_decision`. Also the entry point when the
  visitor lets a CV go on after a manual review.
  """
  use Reactor

  alias Portfolio.RecruitingDemo.Agents.Researcher
  alias Portfolio.RecruitingDemo.Changes.SearchProfile

  alias Portfolio.RecruitingDemo.Pipeline.{
    AgentStep,
    InputStep,
    MatchWithVerification,
    Middleware,
    SystemStep
  }

  middlewares do
    middleware Middleware
  end

  input :application_id

  step :topics do
    argument :application_id, input(:application_id)

    run fn %{application_id: id}, _context ->
      {:ok, Enum.map(SearchProfile.topics(), &%{application_id: id, topic: &1})}
    end
  end

  # One Researcher per topic, concurrently: visible in the journal timestamps
  map :research do
    source result(:topics)
    allow_async? true

    step :research_input, {InputStep, agent: Researcher} do
      argument :args, element(:research)
    end

    step :researcher, {AgentStep, agent: Researcher} do
      argument :input, result(:research_input)
      max_retries 0
    end

    return :researcher
  end

  step :start_matching, {SystemStep, action: :start_matching} do
    argument :application_id, input(:application_id)
    wait_for :research
  end

  step :match_with_verification, MatchWithVerification do
    argument :application_id, input(:application_id)
    wait_for :start_matching
  end

  step :await_decision, {SystemStep, action: :await_decision} do
    argument :application_id, input(:application_id)
    wait_for :match_with_verification
  end

  return :await_decision
end
