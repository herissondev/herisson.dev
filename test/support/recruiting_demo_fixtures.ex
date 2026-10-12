defmodule Portfolio.RecruitingDemo.Fixtures do
  @moduledoc "Builds demo records for tests, each in its own visitor session."

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Actor
  alias Portfolio.RecruitingDemo.Resources.{Application, CvSubmission, JobOffer}

  def session_id, do: RecruitingDemo.new_session_id()

  def job_offer(session_id, attrs \\ %{}) do
    JobOffer
    |> Ash.Changeset.for_create(
      :configure,
      Map.merge(
        %{
          title: "Backend Elixir developer",
          salary_min: 50_000,
          salary_max: 65_000,
          min_years: 3,
          required_skills: ["Elixir", "Phoenix", "PostgreSQL"],
          nice_to_have_skills: ["Ash"],
          location: "Grenoble",
          remote: :hybrid
        },
        attrs
      ),
      actor: Actor.human(session_id)
    )
    |> Ash.create!()
  end

  def cv(session_id, attrs \\ %{}) do
    CvSubmission
    |> Ash.Changeset.for_create(
      :submit,
      Map.merge(
        %{
          template_id: "aligned",
          name: "Camille Martin",
          email: "camille.martin@example.test",
          headline: "Elixir developer",
          years_experience: 5,
          experiences: [%{company: "Acme", role: "Backend developer", start_year: 2020}],
          skills: ["Elixir", "Phoenix"],
          raw_text: "Camille Martin, Elixir developer at Acme since 2020.",
          age: 34,
          family_status: "married",
          origin: "French"
        },
        attrs
      ),
      actor: Actor.human(session_id)
    )
    |> Ash.create!()
  end

  def application(session_id) do
    offer = job_offer(session_id)
    cv = cv(session_id)

    Application
    |> Ash.Changeset.for_create(:submit, %{job_offer_id: offer.id, cv_submission_id: cv.id},
      actor: Actor.human(session_id)
    )
    |> Ash.create!()
  end

  @doc "Runs an Application update action as `actor`."
  def transition(application, action, actor, params \\ %{}) do
    application
    |> Ash.Changeset.for_update(action, params, actor: actor)
    |> Ash.update()
  end

  def transition!(application, action, actor, params \\ %{}) do
    {:ok, application} = transition(application, action, actor, params)
    application
  end

  @doc "Moves a fresh application to `:matching` the way the pipeline would."
  def application_in_matching(session_id) do
    system = Actor.system(session_id)

    session_id
    |> application()
    |> transition!(:start_triage, system)
    |> transition!(:record_triage, Actor.agent(:triage, session_id), %{
      triage_category: :relevant,
      triage_confidence: 0.95,
      triage_source: :simulated
    })
    |> transition!(:route_after_triage, system)
    |> transition!(:start_matching, system)
  end
end
