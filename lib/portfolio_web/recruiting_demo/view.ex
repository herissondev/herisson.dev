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

  def agent_rights("triage"), do: gettext("Reads the CV text and the job title. No tools.")

  def agent_rights("researcher"),
    do: gettext("Reads the name and declared experiences. Never the offer.")

  def agent_rights("matcher"),
    do: gettext("Reads the CV (without protected criteria), research and full offer.")

  def agent_rights("writer"),
    do: gettext("Reads the verdict, key points and job title. Never the CV nor the salary.")

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

  @doc "Line diff between the agent's draft and the visitor's text."
  def diff(old, new) do
    lines = fn %{"subject" => subject, "body" => body} ->
      ["Subject: " <> (subject || "") | String.split(body || "", "\n")]
    end

    old
    |> lines.()
    |> List.myers_difference(lines.(new))
    |> Enum.flat_map(fn {op, chunk} -> Enum.map(chunk, &{op, &1}) end)
  end

  def pretty(term), do: Jason.encode!(term, pretty: true)
end
