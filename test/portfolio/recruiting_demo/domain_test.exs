defmodule Portfolio.RecruitingDemo.DomainTest do
  use ExUnit.Case, async: true

  import Portfolio.RecruitingDemo.Fixtures

  alias Portfolio.RecruitingDemo.{Actor, AuditLog}
  alias Portfolio.RecruitingDemo.Resources.{Assessment, EmailDraft, OutboxEmail, ResearchRequest}

  setup do
    sid = session_id()
    %{sid: sid, system: Actor.system(sid), human: Actor.human(sid)}
  end

  describe "state machine" do
    test "an undeclared transition is refused, whoever attempts it", %{sid: sid} = ctx do
      application = application(sid)

      # received -> matching / awaiting_decision / sent are not declared
      for {action, actor, params} <- [
            {:start_matching, ctx.system, %{}},
            {:await_decision, ctx.system, %{}},
            {:decide, ctx.human, %{decision: :yes}},
            {:send_email, ctx.human, %{subject: "s", body: "b"}}
          ] do
        assert {:error,
                %Ash.Error.Invalid{errors: [%AshStateMachine.Errors.NoMatchingTransition{}]}} =
                 transition(application, action, actor, params)
      end
    end

    test "triage routes on category and the confidence threshold", %{sid: sid} = ctx do
      route = fn category, confidence ->
        sid
        |> application()
        |> transition!(:start_triage, ctx.system)
        |> transition!(:record_triage, Actor.agent(:triage, sid), %{
          triage_category: category,
          triage_confidence: confidence,
          triage_source: :simulated
        })
        |> transition!(:route_after_triage, ctx.system)
        |> Map.fetch!(:state)
      end

      assert route.(:relevant, 0.9) == :researching
      assert route.(:unrelated, 0.95) == :rejected
      assert route.(:off_position, 0.8) == :rejected
      assert route.(:suspect, 0.9) == :manual_review
      # Below the threshold the visitor decides, even for a clear-cut category
      assert route.(:unrelated, 0.4) == :manual_review
    end

    test "the triage agent cannot move the state itself", %{sid: sid} = ctx do
      application = sid |> application() |> transition!(:start_triage, ctx.system)

      assert {:error, %Ash.Error.Forbidden{}} =
               transition(application, :route_after_triage, Actor.agent(:triage, sid))
    end

    test "any automatic state can fail, waiting states cannot", %{sid: sid} = ctx do
      application = application_in_matching(sid)

      assert {:ok, %{state: :failed}} =
               transition(application, :fail, ctx.system, %{failure_reason: "timeout"})

      waiting = sid |> application_in_matching() |> transition!(:await_decision, ctx.system)
      assert {:error, %Ash.Error.Invalid{}} = transition(waiting, :fail, ctx.system)
    end

    test "full happy path to the fake outbox", %{sid: sid} = ctx do
      application =
        sid
        |> application_in_matching()
        |> transition!(:await_decision, ctx.system)
        |> transition!(:decide, ctx.human, %{decision: :yes})

      assert application.state == :drafting

      create_draft!(application, sid)
      application = transition!(application, :mark_draft_ready, ctx.system)

      edited =
        EmailDraft
        |> Ash.Changeset.for_create(
          :edit_draft,
          %{
            application_id: application.id,
            subject: "Your application",
            body: "Hello Camille,\nSee you soon"
          },
          actor: ctx.human
        )
        |> Ash.create!()

      assert edited.version == 2
      assert edited.author_kind == :human

      application =
        transition!(application, :send_email, ctx.human, %{
          subject: edited.subject,
          body: edited.body
        })

      assert application.state == :sent

      assert [%{to: "camille.martin@example.test", sent_by: "human:recruiter"}] =
               Ash.read!(OutboxEmail, actor: ctx.human)
    end
  end

  describe "rules coded, not prompted" do
    test "the Matcher gets at most two verifications", %{sid: sid} do
      application = application_in_matching(sid)
      matcher = Actor.agent(:matcher, sid)

      request = fn question ->
        ResearchRequest
        |> Ash.Changeset.for_create(
          :request_verification,
          %{application_id: application.id, question: question},
          actor: matcher
        )
        |> Ash.create()
      end

      assert {:ok, _} = request.("Did they work at Acme?")
      assert {:ok, _} = request.("Is Acme a real company?")
      assert {:error, %Ash.Error.Invalid{}} = request.("One more?")
    end

    test "key points handed to the Writer cannot carry compensation", %{sid: sid} do
      application = application_in_matching(sid)

      submit = fn key_points ->
        Assessment
        |> Ash.Changeset.for_create(
          :submit_assessment,
          %{application_id: application.id, recommendation: :yes, key_points: key_points},
          actor: Actor.agent(:matcher, sid)
        )
        |> Ash.create()
      end

      assert {:error, %Ash.Error.Invalid{}} = submit.(["Expects 60k€"])
      assert {:error, %Ash.Error.Invalid{}} = submit.(["Salary in range"])
      assert {:ok, _} = submit.(["Five years of Elixir", "Knows Phoenix"])
    end

    test "records referencing another session are refused", %{sid: sid} do
      other = application_in_matching(session_id())

      assert {:error, %Ash.Error.Invalid{}} =
               ResearchRequest
               |> Ash.Changeset.for_create(
                 :request_verification,
                 %{application_id: other.id, question: "?"},
                 actor: Actor.agent(:matcher, sid)
               )
               |> Ash.create()
    end
  end

  describe "journal" do
    test "every transition and decision is chained and verifiable", %{sid: sid} = ctx do
      application =
        sid
        |> application_in_matching()
        |> transition!(:await_decision, ctx.system)
        |> transition!(:decide, ctx.human, %{decision: :no})

      events = AuditLog.events(application.id, ctx.human)

      assert Enum.map(events, & &1.seq) == Enum.to_list(1..length(events))

      assert [
               %{type: "state_transition", payload: %{"from" => nil, "to" => "received"}},
               %{type: "state_transition", payload: %{"to" => "triaging"}},
               %{type: "state_transition", payload: %{"to" => "researching"}},
               %{type: "state_transition", payload: %{"to" => "matching"}},
               %{type: "state_transition", payload: %{"to" => "awaiting_decision"}},
               %{type: "human_decision", payload: %{"decision" => "no"}},
               %{type: "state_transition", payload: %{"to" => "rejected"}}
             ] = events

      assert AuditLog.verify(events) == :ok
    end

    test "verification fails when an event is altered", %{sid: sid} = ctx do
      events = sid |> application_in_matching() |> Map.fetch!(:id) |> AuditLog.events(ctx.human)

      tampered =
        List.update_at(events, 1, &%{&1 | payload: %{"from" => "received", "to" => "sent"}})

      assert AuditLog.verify(tampered) == {:error, 2}

      reordered = List.update_at(events, 2, &%{&1 | seq: 99})
      assert AuditLog.verify(reordered) == {:error, 99}

      assert AuditLog.verify(Enum.drop(events, 1)) == {:error, 2}
    end

    test "concurrent appends keep a consistent chain", %{sid: sid} = ctx do
      application = application(sid)

      1..20
      |> Task.async_stream(fn i ->
        AuditLog.append(%{
          application_id: application.id,
          actor: Actor.agent(:researcher, sid),
          type: :tool_called,
          payload: %{i: i}
        })
      end)
      |> Enum.each(fn {:ok, {:ok, _}} -> :ok end)

      events = AuditLog.events(application.id, ctx.human)
      assert length(events) == 21
      assert AuditLog.verify(events) == :ok
    end

    test "editing the draft records the diff", %{sid: sid} = ctx do
      application =
        sid
        |> application_in_matching()
        |> transition!(:await_decision, ctx.system)
        |> transition!(:decide, ctx.human, %{decision: :yes})

      create_draft!(application, sid)
      application = transition!(application, :mark_draft_ready, ctx.system)

      EmailDraft
      |> Ash.Changeset.for_create(
        :edit_draft,
        %{application_id: application.id, subject: "Your application", body: "Hello Camille"},
        actor: ctx.human
      )
      |> Ash.create!()

      assert %{payload: %{"from_version" => 1, "to_version" => 2, "diff" => diff}} =
               application.id
               |> AuditLog.events(ctx.human)
               |> Enum.find(&(&1.type == "draft_edited"))

      assert ["del", "Hello"] in diff
      assert ["ins", "Hello Camille"] in diff
    end
  end

  defp create_draft!(application, sid) do
    EmailDraft
    |> Ash.Changeset.for_create(
      :create_draft,
      %{application_id: application.id, subject: "Your application", body: "Hello"},
      actor: Actor.agent(:writer, sid)
    )
    |> Ash.create!()
  end
end
