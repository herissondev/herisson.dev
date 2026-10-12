defmodule Portfolio.RecruitingDemo.Agents.Researcher do
  @moduledoc """
  Researcher: searches one topic (or answers one verification) about the
  candidate's name and declared experiences. Never sees the offer.
  """
  @behaviour Portfolio.RecruitingDemo.Agents.Agent

  alias Portfolio.RecruitingDemo.Agents.Agent
  alias Portfolio.RecruitingDemo.Resources.{Application, CvSubmission}

  @impl true
  def role, do: :researcher

  @impl true
  def input(application_id, actor, args) do
    application = Ash.get!(Application, application_id, actor: actor)
    cv = Ash.get!(CvSubmission, application.cv_submission_id, actor: actor)

    %{
      topic: args[:topic],
      question: args[:question],
      research_request_id: args[:research_request_id],
      candidate: Agent.visible(cv, [:name, :experiences])
    }
  end
end
