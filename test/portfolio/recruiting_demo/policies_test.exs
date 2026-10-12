defmodule Portfolio.RecruitingDemo.PoliciesTest do
  @moduledoc "One assertion per cell of the rights matrix (section 4 of the spec)."
  use ExUnit.Case, async: true

  import Portfolio.RecruitingDemo.Fixtures

  alias Portfolio.RecruitingDemo.Actor

  alias Portfolio.RecruitingDemo.Resources.{
    Application,
    Assessment,
    AuditEvent,
    CvSubmission,
    EmailDraft,
    JobOffer,
    OutboxEmail,
    ResearchRequest,
    ResearchResult
  }

  @actors [:triage, :researcher, :matcher, :writer, :human, :system]

  defp actor(:human, sid), do: Actor.human(sid)
  defp actor(:system, sid), do: Actor.system(sid)
  defp actor(role, sid), do: Actor.agent(role, sid)

  setup do
    sid = session_id()
    %{sid: sid, application: application(sid)}
  end

  # {resource, action, actors allowed}
  @creates [
    {JobOffer, :configure, [:human]},
    {CvSubmission, :submit, [:human]},
    {Application, :submit, [:human]},
    {ResearchRequest, :request_verification, [:matcher]},
    {ResearchResult, :search_profile, [:researcher]},
    {Assessment, :submit_assessment, [:matcher]},
    {EmailDraft, :create_draft, [:writer]},
    {EmailDraft, :edit_draft, [:human]},
    {OutboxEmail, :deliver, [:human]},
    {AuditEvent, :append, []}
  ]

  for {resource, action, allowed} <- @creates, who <- @actors do
    @tag resource: resource, action: action, who: who, allowed: who in allowed
    test "#{inspect(resource)}.#{action} by #{who}: #{if who in allowed, do: "allowed", else: "denied"}",
         %{sid: sid} = tags do
      assert Ash.can?({tags.resource, tags.action}, actor(tags.who, sid)) == tags.allowed
    end
  end

  @application_updates [
    {[
       :start_triage,
       :start_matching,
       :request_research,
       :await_decision,
       :mark_draft_ready,
       :fail
     ], [:system]},
    {[:record_triage], [:triage]},
    {[:review, :decide, :send_email], [:human]}
  ]

  for {actions, allowed} <- @application_updates, action <- actions, who <- @actors do
    @tag action: action, who: who, allowed: who in allowed
    test "Application.#{action} by #{who}: #{if who in allowed, do: "allowed", else: "denied"}",
         %{sid: sid, application: application} = tags do
      assert Ash.can?({application, tags.action}, actor(tags.who, sid)) == tags.allowed
    end
  end

  @reads [
    {JobOffer, [:triage, :matcher, :writer, :human, :system]},
    {CvSubmission, @actors},
    {Application, @actors},
    {ResearchRequest, [:researcher, :matcher, :human, :system]},
    {ResearchResult, [:researcher, :matcher, :human, :system]},
    {Assessment, [:matcher, :writer, :human, :system]},
    {EmailDraft, [:writer, :human, :system]},
    {OutboxEmail, [:human, :system]},
    {AuditEvent, [:human, :system]}
  ]

  for {resource, allowed} <- @reads, who <- @actors do
    @tag resource: resource, who: who, allowed: who in allowed
    test "#{inspect(resource)} read by #{who}: #{if who in allowed, do: "allowed", else: "denied"}",
         %{sid: sid} = tags do
      assert Ash.can?({tags.resource, :read}, actor(tags.who, sid)) == tags.allowed
    end
  end

  # {resource, fields, actors allowed to see them}
  @fields [
    {JobOffer, [:title], [:triage, :matcher, :writer, :human, :system]},
    {JobOffer, [:salary_min, :salary_max, :required_skills], [:matcher, :human, :system]},
    {CvSubmission, [:raw_text], [:triage, :human, :system]},
    {CvSubmission, [:name], [:researcher, :matcher, :writer, :human, :system]},
    {CvSubmission, [:experiences], [:researcher, :matcher, :human, :system]},
    {CvSubmission, [:skills, :headline], [:matcher, :human, :system]},
    {CvSubmission, [:age, :family_status, :origin, :email], [:human, :system]},
    {Assessment, [:recommendation, :key_points], [:matcher, :writer, :human, :system]},
    {Assessment, [:strengths, :weaknesses, :gaps], [:matcher, :human, :system]}
  ]

  for {resource, fields, allowed} <- @fields,
      who <- @actors,
      Enum.any?(@reads, fn {r, readers} -> r == resource and who in readers end) do
    @tag resource: resource, fields: fields, who: who, allowed: who in allowed
    test "#{inspect(resource)} #{inspect(fields)} seen by #{who}: #{if who in allowed, do: "visible", else: "hidden"}",
         %{sid: sid} = tags do
      assert Ash.can_see_fields?(tags.resource, actor(tags.who, sid), tags.fields) ==
               tags.allowed
    end
  end

  test "an actor never sees another visitor's records", %{application: application} do
    for who <- @actors do
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.get(Application, application.id, actor: actor(who, session_id()))
    end
  end

  test "an agent reading the CV gets forbidden fields masked", %{sid: sid, application: app} do
    cv = Ash.get!(CvSubmission, app.cv_submission_id, actor: Actor.agent(:matcher, sid))
    assert cv.name == "Camille Martin"
    assert %Ash.ForbiddenField{} = cv.age
    assert %Ash.ForbiddenField{} = cv.origin
    assert %Ash.ForbiddenField{} = cv.raw_text

    offer = Ash.get!(JobOffer, app.job_offer_id, actor: Actor.agent(:writer, sid))
    assert offer.title == "Backend Elixir developer"
    assert %Ash.ForbiddenField{} = offer.salary_max
  end

  test "no agent can send the email, even when the call is forced", %{sid: sid} do
    application = draft_ready(sid)

    for role <- Actor.agent_roles() do
      assert {:error, %Ash.Error.Forbidden{}} =
               transition(application, :send_email, Actor.agent(role, sid), %{
                 subject: "Hello",
                 body: "You are hired"
               })

      assert {:error, %Ash.Error.Forbidden{}} =
               OutboxEmail
               |> Ash.Changeset.for_create(
                 :deliver,
                 %{application_id: application.id, to: "x", subject: "s", body: "b"},
                 actor: Actor.agent(role, sid)
               )
               |> Ash.create()
    end
  end

  defp draft_ready(sid) do
    system = Actor.system(sid)

    application =
      sid
      |> application_in_matching()
      |> transition!(:await_decision, system)
      |> transition!(:decide, Actor.human(sid), %{decision: :yes})

    EmailDraft
    |> Ash.Changeset.for_create(
      :create_draft,
      %{application_id: application.id, subject: "Your application", body: "Hello"},
      actor: Actor.agent(:writer, sid)
    )
    |> Ash.create!()

    transition!(application, :mark_draft_ready, system)
  end

  test "the journal can only be appended through AuditLog", %{sid: sid, application: app} do
    assert {:error, %Ash.Error.Forbidden{}} =
             AuditEvent
             |> Ash.Changeset.for_create(
               :append,
               %{
                 session_id: sid,
                 application_id: app.id,
                 seq: 99,
                 at: DateTime.utc_now(),
                 actor_kind: "human",
                 actor_role: "recruiter",
                 type: "email_sent",
                 prev_hash: "x",
                 hash: "y"
               },
               actor: Actor.human(sid)
             )
             |> Ash.create()

    refute Ash.Resource.Info.action(AuditEvent, :update)
    refute Ash.Resource.Info.action(AuditEvent, :destroy)
  end
end
