defmodule PortfolioWeb.RecruitingDemo.View do
  @moduledoc """
  Everything the pipeline view shows is derived from the journal, so the
  live view and the replay are the same function of a list of events.
  """
  use Gettext, backend: PortfolioWeb.Gettext

  @agents ~w(triage researcher matcher writer)

  def agents, do: @agents

  def agent_name("triage"), do: gettext("Triage")
  def agent_name("researcher"), do: gettext("Researcher")
  def agent_name("matcher"), do: gettext("Matcher")
  def agent_name("writer"), do: gettext("Writer")
  def agent_name("recruiter"), do: gettext("You")
  def agent_name("orchestrator"), do: gettext("Orchestrator")
  def agent_name(other), do: other

  def agent_model("triage"), do: "Jev"
  def agent_model(_), do: "LLM"

  @doc "What an agent is allowed to see, in plain words."
  def agent_sees("triage"), do: gettext("the CV text and the job title")
  def agent_sees("researcher"), do: gettext("the candidate's name and declared experiences")
  def agent_sees("matcher"), do: gettext("the CV, the research and the full job offer")
  def agent_sees("writer"), do: gettext("the verdict, the key points and the job title")

  @doc "What an agent never gets, whatever its model asks for."
  def agent_never("triage"), do: gettext("salary, offer details, any tool")
  def agent_never("researcher"), do: gettext("the job offer, the salary, the Matcher's report")
  def agent_never("matcher"), do: gettext("age, family situation, origin; sending emails")
  def agent_never("writer"), do: gettext("the raw CV, the salary; sending emails")

  @doc """
  The six steps of the pipeline, derived from the events only (so the
  replay shows the same thing). Each step has a status among
  `:waiting | :running | :done | :action | :failed | :skipped`.
  """
  def steps(events) do
    state = state(events)
    cards = Map.new(@agents, &{&1, agent_card(events, &1)})

    decision =
      Enum.find(events, &(&1.type == "human_decision" and Map.has_key?(&1.payload, "decision")))

    steps = [
      %{
        key: :triage,
        agent: "triage",
        title: gettext("Sorting"),
        status: agent_status(cards["triage"], state == "manual_review"),
        summary: triage_summary(events, state)
      },
      %{
        key: :research,
        agent: "researcher",
        title: gettext("Background check"),
        status: agent_status(cards["researcher"]),
        summary: research_summary(events)
      },
      %{
        key: :analysis,
        agent: "matcher",
        title: gettext("Analysis"),
        status: agent_status(cards["matcher"]),
        summary: analysis_summary(events)
      },
      %{
        key: :decision,
        agent: nil,
        title: gettext("Your decision"),
        status: decision_status(state, decision),
        summary: decision_summary(state, decision)
      },
      %{
        key: :writing,
        agent: "writer",
        title: gettext("Email draft"),
        status: agent_status(cards["writer"]),
        summary: writing_summary(cards["writer"])
      },
      %{
        key: :sending,
        agent: nil,
        title: gettext("Sending"),
        status: sending_status(state),
        summary: sending_summary(state)
      }
    ]

    skip_after_stop(steps, state)
  end

  defp agent_status(card, needs_you? \\ false)
  defp agent_status(_card, true), do: :action
  defp agent_status(%{status: :failed}, _), do: :failed
  defp agent_status(%{status: :running}, _), do: :running
  defp agent_status(%{runs: runs}, _) when runs > 0, do: :done
  defp agent_status(_card, _), do: :waiting

  defp decision_status("awaiting_decision", _), do: :action
  defp decision_status(_state, nil), do: :waiting
  defp decision_status(_state, _decision), do: :done

  defp sending_status("draft_ready"), do: :action
  defp sending_status("sent"), do: :done
  defp sending_status(_state), do: :waiting

  # Once the application is rejected or failed, the remaining steps never run
  defp skip_after_stop(steps, state) when state in ["rejected", "failed"],
    do: Enum.map(steps, &if(&1.status == :waiting, do: %{&1 | status: :skipped}, else: &1))

  defp skip_after_stop(steps, _state), do: steps

  defp triage_summary(_events, "manual_review"), do: gettext("Ambiguous case: your call")

  defp triage_summary(events, _state) do
    case last_output(events, "triage") do
      %{"category" => category, "confidence" => confidence} ->
        gettext("%{category} · confidence %{percent}%",
          category: category |> String.to_existing_atom() |> category_label(),
          percent: round(confidence * 100)
        )

      _ ->
        nil
    end
  end

  defp research_summary(events) do
    searches =
      Enum.count(
        events,
        &(&1.type == "tool_called" and &1.payload["topic"] in ~w(experiences companies skills))
      )

    checks = Enum.count(events, &(&1.type == "agent_message"))

    cond do
      searches == 0 ->
        nil

      checks == 0 ->
        ngettext("1 search", "%{count} searches in parallel", searches)

      true ->
        ngettext(
          "%{count} searches, 1 extra check",
          "%{count} searches, %{checks} extra checks",
          checks,
          count: searches,
          checks: checks
        )
    end
  end

  defp analysis_summary(events) do
    case Enum.find(
           events,
           &(&1.type == "tool_called" and Map.has_key?(&1.payload, "recommendation"))
         ) do
      %{payload: %{"recommendation" => rec}} ->
        gettext("Recommendation: %{rec}",
          rec: rec |> String.to_existing_atom() |> recommendation_label()
        )

      nil ->
        nil
    end
  end

  defp decision_summary("awaiting_decision", _), do: gettext("Your turn: send an email or not?")
  defp decision_summary(_state, %{payload: %{"decision" => "yes"}}), do: gettext("You said yes")
  defp decision_summary(_state, %{payload: %{"decision" => "no"}}), do: gettext("You said no")
  defp decision_summary(_state, _), do: nil

  defp writing_summary(%{runs: runs}) when runs > 0, do: gettext("Draft written by the AI")
  defp writing_summary(_card), do: nil

  defp sending_summary("draft_ready"), do: gettext("Your turn: review and send")
  defp sending_summary("sent"), do: gettext("Sent to the fake outbox")
  defp sending_summary(_state), do: nil

  defp last_output(events, agent) do
    events
    |> Enum.filter(&(&1.type == "agent_output" and &1.payload["agent"] == agent))
    |> List.last()
    |> case do
      nil -> nil
      event -> event.payload["output"]
    end
  end

  @doc "A tool, as an action in plain words."
  def tool_action("send_email"), do: gettext("send the email")
  def tool_action(tool), do: tool

  @doc "Tool calls refused by a policy, with the agent that tried."
  def refusals(events), do: Enum.filter(events, &(&1.type == "tool_denied"))

  @doc "State of an agent card: `:waiting | :running | :done | :refused | :failed`, plus details."
  def agent_card(events, agent) do
    inputs = Enum.filter(events, &(&1.type == "agent_input" and &1.payload["agent"] == agent))
    outputs = Enum.filter(events, &(&1.type == "agent_output" and &1.payload["agent"] == agent))
    denied = Enum.filter(events, &(&1.type == "tool_denied" and &1.actor_role == agent))
    tools = Enum.filter(events, &(&1.type == "tool_called" and &1.actor_role == agent))
    failed = Enum.filter(events, &(&1.type == "step_failed" and step_agent(&1) == agent))

    status =
      cond do
        failed != [] -> :failed
        length(inputs) > length(outputs) -> :running
        denied != [] -> :refused
        outputs != [] -> :done
        true -> :waiting
      end

    %{
      agent: agent,
      status: status,
      runs: length(outputs),
      inputs: inputs,
      outputs: outputs,
      tools: tools,
      denied: denied,
      failed: failed
    }
  end

  defp step_agent(%{payload: %{"step" => step}}) do
    Enum.find(@agents, &String.contains?(step, &1))
  end

  def status_label(:waiting), do: gettext("waiting")
  def status_label(:running), do: gettext("running")
  def status_label(:done), do: gettext("done")
  def status_label(:refused), do: gettext("refused")
  def status_label(:failed), do: gettext("failed")

  def status_variant(:refused), do: "destructive"
  def status_variant(:failed), do: "destructive"
  def status_variant(:running), do: "default"
  def status_variant(_), do: "secondary"

  @doc "Current application state, from the last transition in the events."
  def state(events) do
    events
    |> Enum.filter(&(&1.type == "state_transition"))
    |> List.last()
    |> case do
      nil -> nil
      event -> event.payload["to"]
    end
  end

  def state_label("received"), do: gettext("received")
  def state_label("triaging"), do: gettext("triaging")
  def state_label("researching"), do: gettext("researching")
  def state_label("matching"), do: gettext("matching")
  def state_label("manual_review"), do: gettext("manual review")
  def state_label("awaiting_decision"), do: gettext("awaiting your decision")
  def state_label("drafting"), do: gettext("drafting")
  def state_label("draft_ready"), do: gettext("draft ready")
  def state_label("sent"), do: gettext("sent")
  def state_label("rejected"), do: gettext("rejected")
  def state_label("failed"), do: gettext("failed")
  def state_label(nil), do: "-"
  def state_label(other), do: to_string(other)

  def recommendation_label(:strong_yes), do: gettext("Strong yes")
  def recommendation_label(:yes), do: gettext("Yes")
  def recommendation_label(:maybe), do: gettext("Maybe")
  def recommendation_label(:no), do: gettext("No")
  def recommendation_label(other), do: to_string(other)

  def category_label(:relevant), do: gettext("relevant")
  def category_label(:off_position), do: gettext("off position")
  def category_label(:unrelated), do: gettext("unrelated")
  def category_label(:suspect), do: gettext("suspect")
  def category_label(other), do: to_string(other)

  @doc "Messages exchanged between agents (Matcher -> Researcher and back)."
  def messages(events) do
    Enum.flat_map(events, fn
      %{type: "agent_message", payload: %{"question" => question}} = event ->
        [%{seq: event.seq, from: "matcher", to: "researcher", text: question}]

      %{
        type: "agent_output",
        payload: %{"agent" => "researcher", "output" => %{"answering" => _}}
      } = event ->
        [
          %{
            seq: event.seq,
            from: "researcher",
            to: "matcher",
            text: gettext("Verification done, results recorded")
          }
        ]

      _ ->
        []
    end)
  end

  @doc "One-line summary of a journal event."
  def summary(%{type: "state_transition", payload: %{"from" => nil, "to" => to}}),
    do: gettext("Application %{state}", state: state_label(to))

  def summary(%{type: "state_transition", payload: %{"from" => from, "to" => to}}),
    do: "#{state_label(from)} → #{state_label(to)}"

  def summary(%{type: "agent_input", payload: %{"agent" => agent}}),
    do: gettext("%{agent} receives its context", agent: agent_name(agent))

  def summary(%{type: "agent_output", payload: %{"agent" => agent} = payload}),
    do:
      gettext("%{agent} answers (%{model}, %{ms} ms)",
        agent: agent_name(agent),
        model: payload["model"],
        ms: payload["latency_ms"]
      )

  def summary(%{type: "tool_called", payload: payload, actor_role: role}),
    do:
      gettext("%{agent} calls a tool: %{detail}",
        agent: agent_name(role),
        detail: tool_detail(payload)
      )

  def summary(%{type: "tool_denied", payload: %{"tool" => tool}, actor_role: role}),
    do: gettext("Policy refuses %{tool} to %{agent}", tool: tool, agent: agent_name(role))

  def summary(%{type: "agent_message", payload: %{"question" => question}}),
    do: gettext("Matcher asks the Researcher: %{question}", question: question)

  def summary(%{type: "human_decision", payload: %{"decision" => decision}}),
    do: gettext("You decide: %{decision}", decision: decision)

  def summary(%{type: "human_decision", payload: %{"approve" => approve}}),
    do: if(approve, do: gettext("You let the CV go on"), else: gettext("You reject the CV"))

  def summary(%{type: "draft_edited", payload: payload}),
    do:
      gettext("You edit the draft (v%{from} → v%{to})",
        from: payload["from_version"],
        to: payload["to_version"]
      )

  def summary(%{type: "email_sent", payload: %{"to" => to}}),
    do: gettext("You send the email to %{to} (fake outbox)", to: to)

  def summary(%{type: "step_failed", payload: payload}),
    do: gettext("Step %{step} failed: %{error}", step: payload["step"], error: payload["error"])

  def summary(%{type: "compensated", payload: payload}),
    do: gettext("Compensation: %{action}", action: payload["action"])

  def summary(%{type: type}), do: type

  defp tool_detail(%{"topic" => topic}), do: "search_profile (#{topic})"
  defp tool_detail(%{"recommendation" => rec}), do: "submit_assessment (#{rec})"
  defp tool_detail(%{"version" => version}), do: "create_draft (v#{version})"
  defp tool_detail(payload), do: inspect(payload)

  def type_variant("tool_denied"), do: "destructive"
  def type_variant("step_failed"), do: "destructive"
  def type_variant("human_decision"), do: "default"
  def type_variant("email_sent"), do: "default"
  def type_variant(_), do: "outline"

  def time(%{at: at}), do: Calendar.strftime(at, "%H:%M:%S.%f") |> String.slice(0, 12)

  def actor(%{actor_kind: "agent", actor_role: role}), do: agent_name(role)
  def actor(%{actor_role: role}), do: agent_name(role)

  def pretty(term), do: Jason.encode!(term, pretty: true)
end
