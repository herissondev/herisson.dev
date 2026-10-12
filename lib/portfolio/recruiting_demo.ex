defmodule Portfolio.RecruitingDemo do
  @moduledoc """
  Recruiting demo: four AI agents with partitioned rights screen a CV,
  the visitor alone decides and sends the email.

  This is an isolated context. It reads nothing from the CV site, the CV
  site never calls it, and it can be switched off with the `:enabled` flag
  in `config :portfolio, Portfolio.RecruitingDemo`.
  """
  use Boundary, top_level?: true, deps: [], exports: [Supervisor, RateLimit]

  @doc "Whether the demo is switched on."
  def enabled?, do: Keyword.get(config(), :enabled, false)

  @doc "Demo configuration (`config :portfolio, Portfolio.RecruitingDemo`)."
  def config, do: Application.get_env(:portfolio, __MODULE__, [])

  @doc "Topic on which a visitor's pipeline updates are broadcast."
  def topic(session_id), do: "recruiting_demo:" <> session_id

  @doc "PubSub server shared with the host application."
  def pubsub, do: Keyword.fetch!(config(), :pubsub)

  @doc "A fresh opaque visitor session id."
  def new_session_id, do: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

  require Ash.Query

  alias __MODULE__.{Actor, AuditLog, Catalog, Pipeline, RateLimit}
  alias __MODULE__.Changes.RouteTriage

  alias __MODULE__.Resources.{
    Application,
    Assessment,
    CvSubmission,
    EmailDraft,
    JobOffer,
    OutboxEmail
  }

  @doc "Subscribes the caller to a visitor's journal events."
  def subscribe(session_id), do: Phoenix.PubSub.subscribe(pubsub(), topic(session_id))

  def default_offer(locale \\ "en"), do: Catalog.job_offer(locale)
  def cv_templates(locale \\ "en"), do: Catalog.cvs(locale)
  def cv_template(template_id, locale \\ "en"), do: Catalog.cv_attributes(template_id, locale)
  def triage_threshold, do: RouteTriage.threshold()

  @doc """
  Creates the offer, the CV and the application as the visitor, then starts
  screening. Options: `:ip` (rate limiting), `:locale`, `:async?`.
  """
  def submit(session_id, offer_attrs, cv_attrs, opts \\ []) do
    human = Actor.human(session_id)

    with :ok <- rate_limit(opts[:ip]),
         {:ok, offer} <- create(JobOffer, :configure, offer_attrs, human),
         {:ok, cv} <- create(CvSubmission, :submit, cv_attrs, human),
         {:ok, application} <-
           create(Application, :submit, %{job_offer_id: offer.id, cv_submission_id: cv.id}, human) do
      Pipeline.screen(application, opts)
      {:ok, application}
    end
  end

  @doc "The visitor's choice after a manual review: go on with research, or reject."
  def review(session_id, application_id, approve?, opts \\ []) do
    with {:ok, application} <-
           human_update(session_id, application_id, :review, %{approve: approve?}) do
      if application.state == :researching, do: Pipeline.resume_matching(application, opts)
      {:ok, application}
    end
  end

  @doc "The visitor's answer to \"send an email to this candidate?\"."
  def decide(session_id, application_id, decision, opts \\ []) when decision in [:yes, :no] do
    with {:ok, application} <-
           human_update(session_id, application_id, :decide, %{decision: decision}) do
      if application.state == :drafting, do: Pipeline.draft(application, opts)
      {:ok, application}
    end
  end

  @doc "Saves the visitor's version of the draft."
  def edit_draft(session_id, application_id, subject, body) do
    create(
      EmailDraft,
      :edit_draft,
      %{application_id: application_id, subject: subject, body: body},
      Actor.human(session_id)
    )
  end

  @doc "The only way an email is ever sent: by the visitor, to the fake outbox."
  def send_email(session_id, application_id, subject, body) do
    human_update(session_id, application_id, :send_email, %{subject: subject, body: body})
  end

  @doc "The visitor's applications, newest first."
  def applications(session_id) do
    Application
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:cv_submission])
    |> Ash.read!(actor: Actor.human(session_id))
  end

  @doc "Demo button: makes an agent try `send_email`; the policy refuses it."
  def force_forbidden_call(session_id, application_id, agent, opts \\ []) do
    with {:ok, application} <-
           Ash.get(Application, application_id, actor: Actor.human(session_id)) do
      Pipeline.force_forbidden_call(application, agent, opts)
      {:ok, application}
    end
  end

  @doc "Everything the visitor can see about an application."
  def snapshot(session_id, application_id) do
    human = Actor.human(session_id)

    with {:ok, application} <- Ash.get(Application, application_id, actor: human) do
      by_application = fn resource, sort ->
        resource
        |> Ash.Query.filter(application_id == ^application_id)
        |> Ash.Query.sort(sort)
        |> Ash.read!(actor: human)
      end

      {:ok,
       %{
         application: application,
         offer: Ash.get!(JobOffer, application.job_offer_id, actor: human),
         cv: Ash.get!(CvSubmission, application.cv_submission_id, actor: human),
         assessment: Assessment |> by_application.(inserted_at: :desc) |> List.first(),
         drafts: by_application.(EmailDraft, version: :asc),
         outbox: by_application.(OutboxEmail, sent_at: :asc),
         events: AuditLog.events(application_id, human)
       }}
    end
  end

  @doc "Journal of an application, in order."
  def journal(session_id, application_id),
    do: AuditLog.events(application_id, Actor.human(session_id))

  @doc "Recomputes the hash chain: `:ok` or `{:error, seq}`."
  def verify_journal(events), do: AuditLog.verify(events)

  @doc "The journal as plain maps, for the JSON export."
  def export_journal(events) do
    Enum.map(events, fn event ->
      Map.take(event, [:seq, :at, :actor_kind, :actor_role, :type, :payload, :prev_hash, :hash])
    end)
  end

  defp rate_limit(nil), do: :ok

  defp rate_limit(ip) do
    if RateLimit.allow_application?(ip), do: :ok, else: {:error, :rate_limited}
  end

  defp create(resource, action, params, actor) do
    resource |> Ash.Changeset.for_create(action, params, actor: actor) |> Ash.create()
  end

  defp human_update(session_id, application_id, action, params) do
    human = Actor.human(session_id)

    with {:ok, application} <- Ash.get(Application, application_id, actor: human) do
      application |> Ash.Changeset.for_update(action, params, actor: human) |> Ash.update()
    end
  end
end
