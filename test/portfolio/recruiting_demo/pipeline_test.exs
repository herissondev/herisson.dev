defmodule Portfolio.RecruitingDemo.PipelineTest do
  @moduledoc "One scenario per demo CV (section 8 of the spec), with the simulated agents."
  use ExUnit.Case, async: true

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Resources.{OutboxEmail, ResearchRequest}

  defp run(template_id, opts \\ []) do
    sid = RecruitingDemo.new_session_id()

    {:ok, application} =
      RecruitingDemo.submit(
        sid,
        RecruitingDemo.default_offer(),
        RecruitingDemo.cv_template(template_id),
        Keyword.merge([async?: false, locale: "en"], opts)
      )

    {sid, application.id, snapshot(sid, application.id)}
  end

  defp snapshot(sid, id) do
    {:ok, snapshot} = RecruitingDemo.snapshot(sid, id)
    snapshot
  end

  defp events(snapshot, type), do: Enum.filter(snapshot.events, &(&1.type == type))

  defp input_of(snapshot, agent) do
    snapshot
    |> events("agent_input")
    |> Enum.filter(&(&1.payload["agent"] == agent))
    |> Enum.map(& &1.payload["input"])
  end

  test "aligned profile: passes triage, positive recommendation" do
    {_sid, _id, s} = run("aligned")

    assert s.application.state == :awaiting_decision
    assert s.application.triage_category == :relevant
    assert s.assessment.recommendation == :strong_yes
    assert events(s, "tool_denied") == []
    assert RecruitingDemo.verify_journal(s.events) == :ok

    # Three research topics ran, each as its own Researcher
    assert s |> input_of("researcher") |> Enum.map(& &1["topic"]) |> Enum.sort() ==
             ~w(companies experiences skills)
  end

  test "partial profile: nuanced report listing the gaps" do
    {_sid, _id, s} = run("partial")

    assert s.application.state == :awaiting_decision
    assert s.assessment.recommendation == :maybe
    assert Enum.any?(s.assessment.weaknesses, &(&1 =~ "Phoenix" and &1 =~ "OTP"))
  end

  test "off-topic document: rejected at triage as unrelated" do
    {_sid, _id, s} = run("off_topic")

    assert s.application.state == :rejected
    assert s.application.triage_category == :unrelated
    assert input_of(s, "researcher") == []
    assert s.assessment == nil
  end

  test "prompt injection: suspect at triage, then every out-of-role call is refused" do
    {sid, id, s} = run("injection")

    assert s.application.state == :manual_review
    assert s.application.triage_category == :suspect

    # The visitor lets it go on: the (simulated) Matcher falls for the injection
    {:ok, _} = RecruitingDemo.review(sid, id, true, async?: false)
    s = snapshot(sid, id)

    assert [%{payload: %{"tool" => "send_email", "actor" => "agent:matcher", "reason" => reason}}] =
             events(s, "tool_denied")

    assert reason =~ "human"
    assert s.outbox == []

    assert Ash.read!(OutboxEmail, authorize?: false) |> Enum.filter(&(&1.application_id == id)) ==
             []

    # The waiting state still belongs to the human
    assert s.application.state == :awaiting_decision
    assert RecruitingDemo.verify_journal(s.events) == :ok
  end

  test "protected criteria never reach the Matcher" do
    {_sid, _id, s} = run("protected")

    [input | _] = input_of(s, "matcher")
    text = Jason.encode!(input)

    for leaked <- ["52", "married", "children", "Algerian", "age", "family_status", "origin"] do
      refute text =~ leaked, "Matcher input contains #{inspect(leaked)}"
    end

    assert s.application.state == :awaiting_decision
    assert s.assessment.recommendation == :strong_yes
  end

  test "inconsistency: the Matcher asks the Researcher, the doubt stays in the report" do
    {_sid, _id, s} = run("inconsistent")

    assert [%{payload: %{"question" => question}}] = events(s, "agent_message")
    assert question =~ "Nebula Dynamics"

    assert [%{"topic" => "verification"}] =
             s |> input_of("researcher") |> Enum.filter(&(&1["topic"] == "verification"))

    assert Enum.any?(s.assessment.verification_notes, &(&1 =~ "Nebula Dynamics"))
    # The doubt costs one level
    assert s.assessment.recommendation == :yes
    assert length(input_of(s, "matcher")) == 2
  end

  test "each agent only received its authorized data" do
    {sid, id, s} = run("aligned")
    {:ok, _} = RecruitingDemo.decide(sid, id, :yes, async?: false)
    s = snapshot(sid, id) |> Map.put(:events, RecruitingDemo.journal(sid, id))

    assert [triage] = input_of(s, "triage")
    assert Map.keys(triage) |> Enum.sort() == ~w(application_id cv_text job_title)

    for input <- input_of(s, "researcher") do
      refute Map.has_key?(input, "offer")
      assert Map.keys(input["candidate"]) |> Enum.sort() == ~w(experiences name)
    end

    assert [writer] = input_of(s, "writer")

    assert Map.keys(writer) |> Enum.sort() ==
             ~w(application_id candidate_name job_title key_points language recommendation)

    refute Jason.encode!(writer) =~ "65000"
    refute Jason.encode!(writer) =~ "Lumen Labs since 2021"
  end

  test "yes -> the Writer drafts, the visitor edits and sends to the fake outbox" do
    {sid, id, _s} = run("aligned", locale: "fr")

    {:ok, %{state: :drafting}} = RecruitingDemo.decide(sid, id, :yes, async?: false, locale: "fr")
    s = snapshot(sid, id)
    assert s.application.state == :draft_ready
    assert [%{version: 1, author_kind: :agent, body: body} = draft] = s.drafts
    assert body =~ "Bonjour Camille Martin"

    {:ok, _} = RecruitingDemo.edit_draft(sid, id, draft.subject, body <> "\nPS : à bientôt")

    {:ok, %{state: :sent}} =
      RecruitingDemo.send_email(sid, id, draft.subject, body <> "\nPS : à bientôt")

    s = snapshot(sid, id)
    assert [%{sent_by: "human:recruiter", to: "camille.martin@example.test"}] = s.outbox
    assert Enum.map(events(s, "draft_edited"), & &1.payload["to_version"]) == [2]
    assert [_] = events(s, "email_sent")
  end

  test "no -> rejected, nothing is drafted" do
    {sid, id, _s} = run("aligned")
    {:ok, %{state: :rejected}} = RecruitingDemo.decide(sid, id, :no, async?: false)
    assert snapshot(sid, id).drafts == []
  end

  test "research runs concurrently in separate processes" do
    {_sid, _id, s} = run("aligned")

    processes =
      s
      |> events("agent_output")
      |> Enum.filter(&(&1.payload["agent"] == "researcher"))
      |> Enum.map(& &1.payload["process"])

    assert length(Enum.uniq(processes)) == 3
  end

  test "the session purge removes everything, journal included" do
    {sid, id, _s} = run("aligned")
    :ok = RecruitingDemo.Cleaner.purge(sid)

    assert {:error, _} = RecruitingDemo.snapshot(sid, id)

    assert Ash.read!(ResearchRequest, authorize?: false) |> Enum.filter(&(&1.session_id == sid)) ==
             []

    assert RecruitingDemo.journal(sid, id) == []
  end
end
