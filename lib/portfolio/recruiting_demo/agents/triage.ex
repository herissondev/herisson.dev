defmodule Portfolio.RecruitingDemo.Agents.Triage do
  @moduledoc "Triage (Jev): classifies the document from its text and the job title only."
  @behaviour Portfolio.RecruitingDemo.Agents.Agent

  alias Portfolio.RecruitingDemo.Agents.Agent
  alias Portfolio.RecruitingDemo.Resources.{Application, CvSubmission, JobOffer}

  @categories ~w(relevant off_position unrelated suspect)

  def categories, do: @categories

  @impl true
  def role, do: :triage

  @impl true
  def input(application_id, actor, _args) do
    application = Ash.get!(Application, application_id, actor: actor)
    cv = Ash.get!(CvSubmission, application.cv_submission_id, actor: actor)
    offer = Ash.get!(JobOffer, application.job_offer_id, actor: actor)

    %{
      job_title: Agent.visible(offer, [:title])[:title],
      cv_text: Agent.visible(cv, [:raw_text])[:raw_text]
    }
  end
end
