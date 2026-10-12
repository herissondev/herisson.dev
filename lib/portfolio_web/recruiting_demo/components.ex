defmodule PortfolioWeb.RecruitingDemo.Components do
  @moduledoc """
  Demo-specific components (agent card, journal, report, diff, outbox),
  built from the site's own components and tokens.
  """
  use Phoenix.Component
  use Gettext, backend: PortfolioWeb.Gettext

  import PortfolioWeb.CoreComponents, only: [icon: 1]
  import PortfolioWeb.MainComponents, only: [tag: 1]

  alias Phoenix.LiveView.JS
  alias PortfolioWeb.RecruitingDemo.View

  attr :card, :map, required: true
  attr :application, :map, default: nil
  attr :threshold, :float, required: true

  def agent_card(assigns) do
    ~H"""
    <div
      id={"agent-#{@card.agent}"}
      class={[
        "flex flex-col gap-2 rounded border p-3 transition-colors",
        @card.status == :running && "border-gray-400",
        @card.status in [:refused, :failed] && "border-destructive"
      ]}
    >
      <div class="flex items-start justify-between gap-2">
        <div>
          <p class="text-sm font-semibold leading-none">{View.agent_name(@card.agent)}</p>
          <p class="mt-1 font-mono text-xs text-muted-foreground">
            {View.agent_model(@card.agent)}
          </p>
        </div>
        <div class="flex items-center gap-1">
          <.icon :if={@card.status == :running} name="hero-arrow-path" class="h-3 w-3 animate-spin" />
          <.tag text={View.status_label(@card.status)} variant={View.status_variant(@card.status)} />
        </div>
      </div>

      <p class="font-mono text-xs text-muted-foreground">{View.agent_rights(@card.agent)}</p>

      <div :if={@card.agent == "researcher"}>
        <.tag text={gettext("Simulated research")} variant="outline" />
      </div>

      <div
        :if={@card.agent == "triage" && @application && @application.triage_category}
        class="text-xs"
      >
        <span class="font-semibold">{View.category_label(@application.triage_category)}</span>
        <span class="font-mono text-muted-foreground">
          · {gettext("confidence %{value}", value: format_float(@application.triage_confidence))} · {gettext(
            "threshold %{value}",
            value: format_float(@threshold)
          )}
        </span>
      </div>

      <ul :if={@card.tools != []} class="space-y-0.5 font-mono text-xs">
        <li :for={event <- @card.tools} class="text-muted-foreground">
          <.icon name="hero-check-mini" class="h-3 w-3" /> {View.summary(event)}
        </li>
      </ul>

      <ul :if={@card.denied != []} class="space-y-1">
        <li :for={event <- @card.denied} class="rounded bg-destructive/10 p-2 text-xs">
          <p class="font-semibold">
            <.icon name="hero-no-symbol-mini" class="h-3 w-3" />
            {gettext("Refused by policy: %{tool}", tool: event.payload["tool"])}
          </p>
          <details class="mt-1">
            <summary class="cursor-pointer text-muted-foreground">{gettext("Why")}</summary>
            <pre class="mt-1 whitespace-pre-wrap font-mono text-[11px]">{event.payload["reason"]}</pre>
          </details>
        </li>
      </ul>

      <p :for={event <- @card.failed} class="font-mono text-xs text-destructive">
        {event.payload["error"]}
      </p>

      <button
        :if={@card.inputs != []}
        type="button"
        phx-click="show_context"
        phx-value-agent={@card.agent}
        class="self-start text-xs font-semibold underline hover:text-zinc-700"
      >
        {gettext("See this agent's context")} ({length(@card.inputs)})
      </button>
    </div>
    """
  end

  attr :assessment, :map, required: true

  def report(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex items-center gap-2">
        <p class="text-sm font-semibold">{gettext("Matcher's recommendation")}</p>
        <.tag text={View.recommendation_label(@assessment.recommendation)} />
      </div>
      <.report_list title={gettext("Strengths")} items={@assessment.strengths} />
      <.report_list title={gettext("Weaknesses")} items={@assessment.weaknesses} />
      <.report_list title={gettext("Gaps with the position")} items={@assessment.gaps} />
      <.report_list title={gettext("Verification notes")} items={@assessment.verification_notes} />
      <.report_list title={gettext("Quoted from the CV")} items={@assessment.cv_citations} />
    </div>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  defp report_list(assigns) do
    ~H"""
    <div :if={@items != []}>
      <p class="text-xs font-semibold">{@title}</p>
      <ul class="list-disc pl-5 font-mono text-xs text-muted-foreground">
        <li :for={item <- @items}>{item}</li>
      </ul>
    </div>
    """
  end

  attr :lines, :list, required: true

  def diff(assigns) do
    ~H"""
    <div class="overflow-x-auto rounded border font-mono text-xs">
      <div
        :for={{op, line} <- @lines}
        class={[
          "whitespace-pre-wrap px-2",
          op == :del && "bg-destructive/10 line-through",
          op == :ins && "bg-secondary font-semibold"
        ]}
      >
        <span class="select-none text-muted-foreground">{diff_sign(op)}</span> {line}
      </div>
    </div>
    """
  end

  defp diff_sign(:del), do: "-"
  defp diff_sign(:ins), do: "+"
  defp diff_sign(:eq), do: " "

  attr :emails, :list, required: true

  def outbox(assigns) do
    ~H"""
    <div class="space-y-2">
      <div :for={email <- @emails} class="rounded border p-3">
        <p class="font-mono text-xs text-muted-foreground">
          {gettext("To")}: {email.to} · {gettext("sent by")} {email.sent_by} · {Calendar.strftime(
            email.sent_at,
            "%H:%M:%S"
          )}
        </p>
        <p class="mt-1 text-sm font-semibold">{email.subject}</p>
        <pre class="mt-1 whitespace-pre-wrap font-mono text-xs">{email.body}</pre>
      </div>
    </div>
    """
  end

  attr :events, :list, required: true
  attr :integrity, :any, default: nil
  attr :replaying, :boolean, default: false
  attr :export_path, :string, required: true

  def journal(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h2 class="text-lg font-bold">{gettext("Journal")}</h2>
        <span class="font-mono text-xs text-muted-foreground">
          {ngettext("1 event", "%{count} events", length(@events))}
        </span>
      </div>

      <div class="flex flex-wrap gap-2">
        <button type="button" phx-click="replay" disabled={@replaying} class={small_button()}>
          <.icon name="hero-play-mini" class="h-3 w-3" /> {gettext("Replay")}
        </button>
        <button type="button" phx-click="verify" class={small_button()}>
          <.icon name="hero-shield-check-mini" class="h-3 w-3" /> {gettext("Verify integrity")}
        </button>
        <a href={@export_path} download class={small_button()}>
          <.icon name="hero-arrow-down-tray-mini" class="h-3 w-3" /> {gettext("Export JSON")}
        </a>
      </div>

      <p :if={@integrity == :ok} class="font-mono text-xs">
        <.icon name="hero-check-badge-mini" class="h-4 w-4" />
        {gettext("Hash chain verified: no event was altered.")}
      </p>
      <p :if={match?({:error, _}, @integrity)} class="font-mono text-xs text-destructive">
        {gettext("Chain broken at event #%{seq}.", seq: elem(@integrity, 1))}
      </p>

      <ol id="journal-events" class="max-h-[70vh] space-y-1 overflow-y-auto pr-1">
        <li :for={event <- @events} id={"event-#{event.seq}"} class="rounded border px-2 py-1">
          <details>
            <summary class="cursor-pointer list-none text-xs">
              <span class="font-mono text-muted-foreground">#{event.seq} {View.time(event)}</span>
              <span class="font-semibold">{View.actor(event)}</span>
              <.tag text={event.type} variant={View.type_variant(event.type)} />
              <span class="block pt-0.5">{View.summary(event)}</span>
            </summary>
            <pre class="mt-1 max-h-64 overflow-auto whitespace-pre-wrap font-mono text-[11px]">{View.pretty(event.payload)}</pre>
            <p class="truncate font-mono text-[10px] text-muted-foreground">hash {event.hash}</p>
          </details>
        </li>
      </ol>
    </div>
    """
  end

  def small_button,
    do:
      "inline-flex items-center gap-1 rounded-md border px-2 py-1 text-xs font-semibold hover:bg-secondary disabled:opacity-50"

  defp format_float(nil), do: "-"
  defp format_float(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  @doc "Closes the context modal."
  def close_context, do: JS.push("close_context")
end
