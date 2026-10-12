defmodule Portfolio.RecruitingDemo.Pipeline.MatcherReactor do
  @moduledoc "One Matcher turn: build its input, call it, run its tools."
  use Reactor

  alias Portfolio.RecruitingDemo.Agents.Matcher
  alias Portfolio.RecruitingDemo.Pipeline.{AgentStep, InputStep, Middleware}

  middlewares do
    middleware Middleware
  end

  input :application_id

  step :matcher_input, {InputStep, agent: Matcher} do
    argument :application_id, input(:application_id)
  end

  step :matcher, {AgentStep, agent: Matcher} do
    argument :input, result(:matcher_input)
    max_retries 0
  end

  return :matcher
end

defmodule Portfolio.RecruitingDemo.Pipeline.VerificationReactor do
  @moduledoc "The research sub-Reactor run for each Matcher verification request."
  use Reactor

  alias Portfolio.RecruitingDemo.Agents.Researcher
  alias Portfolio.RecruitingDemo.Pipeline.{AgentStep, InputStep, Middleware}

  middlewares do
    middleware Middleware
  end

  input :application_id
  input :research_request_id
  input :question

  step :verification_input, {InputStep, agent: Researcher} do
    argument :application_id, input(:application_id)
    argument :research_request_id, input(:research_request_id)
    argument :question, input(:question)
    argument :topic, value("verification")
  end

  step :researcher, {AgentStep, agent: Researcher} do
    argument :input, result(:verification_input)
    max_retries 0
  end

  return :researcher
end

defmodule Portfolio.RecruitingDemo.Pipeline.DraftingReactor do
  @moduledoc "Started by the visitor's \"yes\": the Writer drafts, then `draft_ready`."
  use Reactor

  alias Portfolio.RecruitingDemo.Agents.Writer
  alias Portfolio.RecruitingDemo.Pipeline.{AgentStep, InputStep, Middleware, SystemStep}

  middlewares do
    middleware Middleware
  end

  input :application_id

  step :writer_input, {InputStep, agent: Writer} do
    argument :application_id, input(:application_id)
  end

  step :writer, {AgentStep, agent: Writer} do
    argument :input, result(:writer_input)
    max_retries 0
  end

  step :mark_draft_ready, {SystemStep, action: :mark_draft_ready} do
    argument :application_id, input(:application_id)
    wait_for :writer
  end

  return :mark_draft_ready
end
