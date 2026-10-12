defmodule PortfolioWeb.RecruitingDemo.Components do
  @moduledoc """
  Demo-specific components (pipeline step, refusals, report, outbox,
  journal), built from the site's own components and tokens.
  """
  use Phoenix.Component
  use Gettext, backend: PortfolioWeb.Gettext

  import PortfolioWeb.CoreComponents, only: [icon: 1]
  import PortfolioWeb.MainComponents, only: [tag: 1]

  alias Phoenix.LiveView.JS
  alias PortfolioWeb.RecruitingDemo.View

  attr :step, :map, required: true
  attr :index, :integer, required: true
  attr :last, :boolean, default: false
  slot :inner_block

  @doc "One step of the vertical pipeline: status dot, title, one-line result, optional body."
  def step(assigns) do
    ~H"""
    <li id={"step-#{@step.key}"} class="relative flex gap-3 pb-6">
      <span :if={!@last} class="absolute left-[13px] top-7 h-full w-px bg-border" aria-hidden="true"></span>
      <.step_dot status={@step.status} index={@index} />
      <div class="min-w-0 flex-1">
        <div class="flex flex-wrap items-baseline gap-x-2">
          <p class={[
            "text-sm font-semibold",
            @step.status == :skipped && "text-muted-foreground line-through"
          ]}>
            {@step.title}
          </p>
          <span :if={@step.agent} class="font-mono text-xs text-muted-foreground">
            {gettext("AI agent")} · {View.agent_model(@step.agent)}
          </span>
          <span :if={!@step.agent} class="font-mono text-xs text-muted-foreground">
            {gettext("you")}
          </span>
        </div>
        <p :if={@step.summary} class={["mt-0.5 text-sm", @step.status == :action && "font-semibold"]}>
          {@step.summary}
        </p>
        <p :if={@step.status == :running} class="mt-0.5 text-sm text-muted-foreground">
          {gettext("in progress…")}
        </p>
        <div :if={@inner_block != []} class="mt-3 space-y-3">{render_slot(@inner_block)}</div>
      </div>
    </li>
    """
  end

  attr :status, :atom, required: true
  attr :index, :integer, required: true

  defp step_dot(assigns) do
    ~H"""
    <span class={[
      "relative z-10 flex h-7 w-7 shrink-0 items-center justify-center rounded-full border text-xs font-semibold",
      @status == :done && "border-zinc-900 bg-zinc-900 text-white",
      @status == :action && "border-zinc-900 bg-white ring-2 ring-zinc-900 ring-offset-2",
      @status == :running && "border-zinc-900 bg-white",
      @status == :failed && "border-destructive bg-destructive text-white",
      @status in [:waiting, :skipped] && "bg-white text-muted-foreground"
    ]}>
      <.icon :if={@status == :done} name="hero-check-mini" class="h-4 w-4" />
      <.icon :if={@status == :running} name="hero-arrow-path-mini" class="h-4 w-4 animate-spin" />
      <.icon :if={@status == :failed} name="hero-x-mark-mini" class="h-4 w-4" />
      <span :if={@status in [:waiting, :skipped, :action]}>{@index}</span>
    </span>
    """
  end

  attr :agent, :string, required: true
  attr :runs, :integer, default: 0

  @doc "What an agent sees and never sees, plus a link to its exact context."
  def agent_rights(assigns) do
    ~H"""
    <details class="rounded border px-3 py-2 text-xs">
      <summary class="cursor-pointer list-none font-semibold">
        <.icon name="hero-eye-mini" class="h-3 w-3" /> {gettext("What this agent is allowed to see")}
      </summary>
      <dl class="mt-2 space-y-1">
        <div>
          <dt class="inline font-semibold">{gettext("Sees:")}</dt>
          <dd class="inline text-muted-foreground">{View.agent_sees(@agent)}</dd>
        </div>
        <div>
          <dt class="inline font-semibold">{gettext("Never gets:")}</dt>
          <dd class="inline text-muted-foreground">{View.agent_never(@agent)}</dd>
        </div>
      </dl>
      <button
        :if={@runs > 0}
        type="button"
        phx-click="show_context"
        phx-value-agent={@agent}
        class="mt-2 font-semibold underline"
      >
        {gettext("See exactly what it received")}
      </button>
    </details>
    """
  end

  attr :refusals, :list, required: true

  @doc "Calls an agent tried and a rule refused (e.g. after a prompt injection)."
  def refusals(assigns) do
    ~H"""
    <div :for={refusal <- @refusals} class="rounded bg-destructive/10 p-3 text-sm">
      <p class="font-semibold">
        <.icon name="hero-no-symbol-mini" class="h-4 w-4" />
        {gettext("Refused: %{agent} tried to %{action}.",
          agent: View.agent_name(refusal.actor_role),
          action: View.tool_action(refusal.payload["tool"])
        )}
      </p>
      <p class="mt-1 text-xs">
        {gettext(
          "Only a human can send an email. The rule is enforced in code, not asked in a prompt: even a fooled AI cannot get around it."
        )}
      </p>
    </div>
    """
  end

  attr :assessment, :map, required: true

  def report(assigns) do
    ~H"""
    <div class="space-y-2 rounded border p-3">
      <div class="flex flex-wrap items-center gap-2">
        <p class="text-sm font-semibold">{gettext("The AI's opinion")}</p>
        <.tag text={View.recommendation_label(@assessment.recommendation)} />
      </div>
      <.report_list title={gettext("Strengths")} items={@assessment.strengths} />
      <.report_list title={gettext("Weaknesses")} items={@assessment.weaknesses} />
      <.report_list title={gettext("Checks")} items={@assessment.verification_notes} />
      <details :if={@assessment.gaps != [] || @assessment.cv_citations != []} class="text-xs">
        <summary class="cursor-pointer font-semibold">{gettext("More detail")}</summary>
        <div class="mt-2 space-y-2">
          <.report_list title={gettext("Gaps with the position")} items={@assessment.gaps} />
          <.report_list title={gettext("Quoted from the CV")} items={@assessment.cv_citations} />
        </div>
      </details>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :items, :list, required: true

  defp report_list(assigns) do
    ~H"""
    <div :if={@items != []}>
      <p class="text-xs font-semibold">{@title}</p>
      <ul class="list-disc space-y-0.5 pl-5 text-sm text-muted-foreground">
        <li :for={item <- @items}>{item}</li>
      </ul>
    </div>
    """
  end

  attr :emails, :list, required: true

  def outbox(assigns) do
    ~H"""
    <div class="space-y-2">
      <div :for={email <- @emails} class="rounded border p-3">
        <p class="break-words font-mono text-xs text-muted-foreground">
          {gettext("To")}: {email.to} · {gettext("sent by")} {email.sent_by}
        </p>
        <p class="mt-1 text-sm font-semibold">{email.subject}</p>
        <pre class="mt-1 whitespace-pre-wrap break-words font-sans text-sm">{email.body}</pre>
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
    <details id="journal" class="rounded border p-3">
      <summary class="cursor-pointer list-none">
        <span class="text-sm font-bold">
          <.icon name="hero-document-text-mini" class="h-4 w-4" /> {gettext("Tamper-proof journal")}
        </span>
        <span class="font-mono text-xs text-muted-foreground">
          · {ngettext("1 event", "%{count} events", length(@events))}
        </span>
        <span class="block text-xs text-muted-foreground">
          {gettext("Every step is recorded, timestamped and chained: for the curious.")}
        </span>
      </summary>

      <div class="mt-3 flex flex-wrap gap-2">
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

      <p :if={@integrity == :ok} class="mt-2 text-xs">
        <.icon name="hero-check-badge-mini" class="h-4 w-4" />
        {gettext("Hash chain verified: no event was altered.")}
      </p>
      <p :if={match?({:error, _}, @integrity)} class="mt-2 text-xs text-destructive">
        {gettext("Chain broken at event #%{seq}.", seq: elem(@integrity, 1))}
      </p>

      <ol id="journal-events" class="mt-3 max-h-[60vh] space-y-1 overflow-y-auto">
        <li :for={event <- @events} id={"event-#{event.seq}"} class="rounded border px-2 py-1">
          <details>
            <summary class="cursor-pointer list-none text-xs">
              <span class="font-mono text-muted-foreground">#{event.seq} {View.time(event)}</span>
              <span class="font-semibold">{View.actor(event)}</span>
              <span class="block break-words pt-0.5">{View.summary(event)}</span>
            </summary>
            <p class="mt-1 font-mono text-[10px] text-muted-foreground">{event.type}</p>
            <pre class="max-h-64 overflow-auto whitespace-pre-wrap break-words font-mono text-[11px]">{View.pretty(event.payload)}</pre>
            <p class="break-all font-mono text-[10px] text-muted-foreground">hash {event.hash}</p>
          </details>
        </li>
      </ol>
    </details>
    """
  end

  def small_button,
    do:
      "inline-flex items-center gap-1 rounded-md border px-2 py-1 text-xs font-semibold hover:bg-secondary disabled:opacity-50"

  @doc "Closes the context modal."
  def close_context, do: JS.push("close_context")
end
