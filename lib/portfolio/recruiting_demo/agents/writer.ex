defmodule Portfolio.RecruitingDemo.Agents.Writer do
  @moduledoc """
  Writer: drafts the email from the verdict, the key points and the job
  title. Never sees the raw CV nor the salary.
  """
  @behaviour Portfolio.RecruitingDemo.Agents.Agent

  require Ash.Query

  alias Portfolio.RecruitingDemo.Agents.Agent
  alias Portfolio.RecruitingDemo.Resources.{Application, Assessment, CvSubmission, JobOffer}

  @impl true
  def role, do: :writer

  @impl true
  def input(application_id, actor, args) do
    application = Ash.get!(Application, application_id, actor: actor)
    cv = Ash.get!(CvSubmission, application.cv_submission_id, actor: actor)
    offer = Ash.get!(JobOffer, application.job_offer_id, actor: actor)

    assessment =
      Assessment
      |> Ash.Query.filter(application_id == ^application_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one!(actor: actor)

    %{
      job_title: Agent.visible(offer, [:title])[:title],
      candidate_name: Agent.visible(cv, [:name])[:name],
      recommendation: assessment && assessment.recommendation,
      key_points: (assessment && assessment.key_points) || [],
      language: args[:locale] || "en"
    }
  end
end
