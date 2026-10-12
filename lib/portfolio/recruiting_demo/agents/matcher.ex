defmodule Portfolio.RecruitingDemo.Agents.Matcher do
  @moduledoc """
  Matcher: compares the CV, the research and the full offer. Its input is
  stripped of protected criteria by `ProtectedCriteria`, in code.
  """
  @behaviour Portfolio.RecruitingDemo.Agents.Agent

  require Ash.Query

  alias Portfolio.RecruitingDemo.Agents.Agent
  alias Portfolio.RecruitingDemo.ProtectedCriteria

  alias Portfolio.RecruitingDemo.Resources.{
    Application,
    CvSubmission,
    JobOffer,
    ResearchRequest,
    ResearchResult
  }

  @impl true
  def role, do: :matcher

  @impl true
  def input(application_id, actor, _args) do
    application = Ash.get!(Application, application_id, actor: actor)
    cv = Ash.get!(CvSubmission, application.cv_submission_id, actor: actor)
    offer = Ash.get!(JobOffer, application.job_offer_id, actor: actor)

    requests =
      ResearchRequest
      |> Ash.Query.filter(application_id == ^application_id)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.read!(actor: actor)

    research =
      ResearchResult
      |> Ash.Query.filter(application_id == ^application_id)
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.read!(actor: actor)
      |> Enum.map(&Agent.visible(&1, [:topic, :findings]))

    %{
      offer:
        Agent.visible(offer, [
          :title,
          :salary_min,
          :salary_max,
          :min_years,
          :required_skills,
          :nice_to_have_skills,
          :location,
          :remote
        ]),
      cv:
        Agent.visible(
          cv,
          [:name, :headline, :years_experience, :skills, :experiences] ++
            ProtectedCriteria.fields()
        ),
      research: research,
      verifications: Enum.map(requests, &Agent.visible(&1, [:question, :status])),
      verifications_left: max(ResearchRequest.max_verifications() - length(requests), 0)
    }
    |> ProtectedCriteria.strip()
  end
end
