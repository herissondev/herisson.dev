defmodule PortfolioWeb.RecruitingDemo.DemoLive do
  @moduledoc """
  The visitor plays the recruiter: configures the position, picks and edits
  a CV, watches the agents, then alone decides and sends the email.
  """
  use PortfolioWeb, :live_view

  import PortfolioWeb.MainComponents, only: [section: 1, tag: 1]
  import PortfolioWeb.RecruitingDemo.Components

  alias Portfolio.RecruitingDemo
  alias PortfolioWeb.RecruitingDemo.{Forms, View}

  @replay_tick_ms 300

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: RecruitingDemo.subscribe(socket.assigns.session_id)

    templates = RecruitingDemo.cv_templates()

    {:ok,
     socket
     |> assign(:page_title, gettext("Recruiting demo"))
     |> assign(:templates, templates)
     |> assign(:tab, :offer)
     |> assign(
       :offer_form,
       to_form(Forms.offer_params(RecruitingDemo.default_offer()), as: :offer)
     )
     |> assign(:cv_form, to_form(Forms.cv_params(hd(templates)), as: :cv))
     |> assign(:threshold, RecruitingDemo.triage_threshold())
     |> assign(:snapshot, nil)
     |> assign(:draft_form, nil)
     |> assign(:replay, nil)
     |> assign(:integrity, nil)
     |> assign(:context_agent, nil)
     |> assign_applications()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case RecruitingDemo.snapshot(socket.assigns.session_id, id) do
      {:ok, snapshot} ->
        {:noreply,
         socket
         |> assign(replay: nil, integrity: nil, context_agent: nil, draft_form: nil)
         |> assign_snapshot(snapshot)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("This application does not exist in your session."))
         |> push_navigate(to: base_path(socket.assigns.locale))}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, assign(socket, :snapshot, nil)}

  @impl true
  def handle_event("tab", %{"tab" => tab}, socket) when tab in ~w(offer cv),
    do: {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}

  def handle_event("offer_change", %{"offer" => params}, socket),
    do: {:noreply, assign(socket, :offer_form, to_form(params, as: :offer))}

  def handle_event("cv_change", %{"cv" => params}, socket),
    do: {:noreply, assign(socket, :cv_form, to_form(params, as: :cv))}

  def handle_event("pick_cv", %{"template" => template_id}, socket) do
    case Enum.find(socket.assigns.templates, &(&1.template_id == template_id)) do
      nil -> {:noreply, socket}
      cv -> {:noreply, assign(socket, cv_form: to_form(Forms.cv_params(cv), as: :cv), tab: :cv)}
    end
  end

  def handle_event("submit", _params, socket) do
    %{session_id: sid, offer_form: offer_form, cv_form: cv_form} = socket.assigns

    case RecruitingDemo.submit(
           sid,
           Forms.offer_attrs(offer_form.params),
           Forms.cv_attrs(cv_form.params),
           ip: socket.assigns.client_ip,
           locale: socket.assigns.locale
         ) do
      {:ok, application} ->
        {:noreply,
         socket
         |> assign_applications()
         |> push_patch(to: application_path(socket.assigns.locale, application.id))}

      {:error, :rate_limited} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Too many applications from your address, try again later.")
         )}

      {:error, error} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("Invalid application: %{error}", error: error_message(error))
         )}
    end
  end

  def handle_event("review", %{"approve" => approve}, socket) do
    act(socket, &RecruitingDemo.review(&1, &2, approve == "true", locale: socket.assigns.locale))
  end

  def handle_event("decide", %{"decision" => decision}, socket) when decision in ~w(yes no) do
    act(
      socket,
      &RecruitingDemo.decide(&1, &2, String.to_existing_atom(decision),
        locale: socket.assigns.locale
      )
    )
  end

  def handle_event("draft_change", %{"draft" => params}, socket),
    do: {:noreply, assign(socket, :draft_form, to_form(params, as: :draft))}

  def handle_event("send_email", _params, socket) do
    %{"subject" => subject, "body" => body} = socket.assigns.draft_form.params
    latest = List.last(socket.assigns.snapshot.drafts)

    act(socket, fn sid, id ->
      with {:ok, _} <- maybe_save_draft(sid, id, latest, subject, body) do
        RecruitingDemo.send_email(sid, id, subject, body)
      end
    end)
  end

  def handle_event("replay", _params, socket) do
    Process.send_after(self(), :replay_tick, @replay_tick_ms)
    {:noreply, assign(socket, replay: 0, integrity: nil)}
  end

  def handle_event("verify", _params, socket) do
    %{session_id: sid, snapshot: %{application: application}} = socket.assigns
    events = RecruitingDemo.journal(sid, application.id)
    {:noreply, assign(socket, :integrity, RecruitingDemo.verify_journal(events))}
  end

  def handle_event("show_context", %{"agent" => agent}, socket)
      when agent in ~w(triage researcher matcher writer),
      do: {:noreply, assign(socket, :context_agent, agent)}

  def handle_event("close_context", _params, socket),
    do: {:noreply, assign(socket, :context_agent, nil)}

  @impl true
  def handle_info({:recruiting_demo, :event, event}, socket) do
    case socket.assigns.snapshot do
      %{application: %{id: id}} when id == event.application_id ->
        {:ok, snapshot} = RecruitingDemo.snapshot(socket.assigns.session_id, id)
        {:noreply, socket |> assign_snapshot(snapshot) |> assign(:integrity, nil)}

      _ ->
        {:noreply, assign_applications(socket)}
    end
  end

  def handle_info(:replay_tick, %{assigns: %{replay: index, snapshot: snapshot}} = socket)
      when is_integer(index) do
    if index >= length(snapshot.events) do
      {:noreply, assign(socket, :replay, nil)}
    else
      Process.send_after(self(), :replay_tick, @replay_tick_ms)
      {:noreply, assign(socket, :replay, index + 1)}
    end
  end

  def handle_info(:replay_tick, socket), do: {:noreply, socket}

  defp act(socket, fun) do
    %{session_id: sid, snapshot: %{application: application}} = socket.assigns

    case fun.(sid, application.id) do
      {:ok, _} ->
        {:ok, snapshot} = RecruitingDemo.snapshot(sid, application.id)
        {:noreply, assign_snapshot(socket, snapshot)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error_message(error))}
    end
  end

  defp maybe_save_draft(_sid, _id, %{subject: subject, body: body} = draft, subject, body),
    do: {:ok, draft}

  defp maybe_save_draft(sid, id, _latest, subject, body),
    do: RecruitingDemo.edit_draft(sid, id, subject, body)

  defp assign_snapshot(socket, snapshot) do
    socket
    |> assign(:snapshot, snapshot)
    |> then(fn socket ->
      if snapshot.application.state == :draft_ready and socket.assigns.draft_form == nil do
        latest = List.last(snapshot.drafts)

        assign(
          socket,
          :draft_form,
          to_form(%{"subject" => latest.subject, "body" => latest.body}, as: :draft)
        )
      else
        socket
      end
    end)
  end

  defp assign_applications(socket),
    do: assign(socket, :applications, RecruitingDemo.applications(socket.assigns.session_id))

  defp base_path(locale), do: "/#{locale}/demo/recruiting"
  defp application_path(locale, id), do: base_path(locale) <> "/#{id}"

  defp error_message(%{errors: [_ | _] = errors}),
    do: Enum.map_join(errors, "; ", &Exception.message/1)

  defp error_message(error) when is_exception(error), do: Exception.message(error)
  defp error_message(error), do: inspect(error)

  # Events shown: all of them, or the first n while replaying
  defp shown_events(%{replay: nil, snapshot: snapshot}), do: snapshot.events
  defp shown_events(%{replay: index, snapshot: snapshot}), do: Enum.take(snapshot.events, index)

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :events, if(assigns.snapshot, do: shown_events(assigns), else: []))

    ~H"""
    <main class="container mx-auto scroll-my-12 overflow-auto p-4 md:p-10">
      <section class="mx-auto w-full max-w-6xl space-y-6 bg-white">
        <div class="flex-1 space-y-1.5">
          <h1 class="text-2xl font-bold">{gettext("Recruiting demo")}</h1>
          <p class="max-w-2xl text-pretty font-mono text-sm text-muted-foreground">
            {gettext(
              "Four AI agents with partitioned rights screen a CV. You play the recruiter: you alone decide and send the email."
            )}
          </p>
          <p class="max-w-2xl rounded border p-2 font-mono text-xs text-muted-foreground">
            {gettext(
              "All data is fictitious and is not kept: everything is erased when your session ends. Web research is simulated."
            )}
          </p>
        </div>

        <nav :if={@applications != []} class="flex flex-wrap items-center gap-2 text-xs">
          <span class="font-semibold">{gettext("Your applications")}:</span>
          <.link
            :for={application <- @applications}
            patch={application_path(@locale, application.id)}
            class={[
              "rounded-md border px-2 py-1 font-mono hover:bg-secondary",
              @snapshot && @snapshot.application.id == application.id && "bg-secondary"
            ]}
          >
            {application.cv_submission.name} · {View.state_label(to_string(application.state))}
          </.link>
          <.link
            patch={base_path(@locale)}
            class="rounded-md border px-2 py-1 font-semibold hover:bg-secondary"
          >
            + {gettext("New application")}
          </.link>
        </nav>

        <.new_application :if={@live_action == :new} {assigns} />
        <.pipeline :if={@live_action == :show && @snapshot} {assigns} />
      </section>
    </main>

    <.modal :if={@context_agent} id="agent-context" show on_cancel={close_context()}>
      <h2 class="text-lg font-bold">
        {gettext("Context received by %{agent}", agent: View.agent_name(@context_agent))}
      </h2>
      <p class="font-mono text-xs text-muted-foreground">
        {gettext("Exactly what was sent to the model, as recorded in the journal.")}
      </p>
      <pre
        :for={event <- View.agent_card(@events, @context_agent).inputs}
        class="mt-3 max-h-96 overflow-auto whitespace-pre-wrap rounded border p-2 font-mono text-[11px]"
      >{View.pretty(event.payload["input"])}</pre>
    </.modal>
    """
  end

  defp new_application(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex gap-4 border-b text-sm font-semibold">
        <button
          type="button"
          phx-click="tab"
          phx-value-tab="offer"
          class={[
            "-mb-px border-b-2 pb-2",
            (@tab == :offer && "border-zinc-900") || "border-transparent text-muted-foreground"
          ]}
        >
          1. {gettext("The position")}
        </button>
        <button
          type="button"
          phx-click="tab"
          phx-value-tab="cv"
          class={[
            "-mb-px border-b-2 pb-2",
            (@tab == :cv && "border-zinc-900") || "border-transparent text-muted-foreground"
          ]}
        >
          2. {gettext("The application")}
        </button>
      </div>

      <.form
        :if={@tab == :offer}
        for={@offer_form}
        id="offer-form"
        phx-change="offer_change"
        class="grid gap-4 sm:grid-cols-2"
      >
        <div class="sm:col-span-2">
          <.input field={@offer_form[:title]} label={gettext("Job title")} />
        </div>
        <.input field={@offer_form[:salary_min]} type="number" label={gettext("Salary min (€/year)")} />
        <.input field={@offer_form[:salary_max]} type="number" label={gettext("Salary max (€/year)")} />
        <.input
          field={@offer_form[:min_years]}
          type="number"
          label={gettext("Minimum years of experience")}
        />
        <.input field={@offer_form[:location]} label={gettext("Location")} />
        <.input
          field={@offer_form[:required_skills]}
          label={gettext("Required skills (comma separated)")}
        />
        <.input
          field={@offer_form[:nice_to_have_skills]}
          label={gettext("Nice to have (comma separated)")}
        />
        <.input
          field={@offer_form[:remote]}
          type="select"
          label={gettext("Remote work")}
          options={[
            {gettext("On site"), "none"},
            {gettext("Hybrid"), "hybrid"},
            {gettext("Full remote"), "full"}
          ]}
        />
      </.form>

      <div :if={@tab == :cv} class="space-y-4">
        <div class="flex flex-wrap gap-2">
          <button
            :for={cv <- @templates}
            type="button"
            phx-click="pick_cv"
            phx-value-template={cv.template_id}
            class={[
              "rounded-md border px-2 py-1 text-left text-xs hover:bg-secondary",
              @cv_form.params["template_id"] == cv.template_id && "bg-secondary"
            ]}
          >
            <span class="font-semibold">{template_label(cv.template_id)}</span>
            <.tag
              text={if cv.kind == "trap", do: gettext("trap"), else: gettext("classic")}
              variant={if cv.kind == "trap", do: "destructive", else: "secondary"}
            />
          </button>
        </div>

        <.form for={@cv_form} id="cv-form" phx-change="cv_change" class="grid gap-4 sm:grid-cols-2">
          <input type="hidden" name="cv[template_id]" value={@cv_form.params["template_id"]} />
          <.input field={@cv_form[:name]} label={gettext("Name")} />
          <.input field={@cv_form[:email]} label={gettext("Email")} />
          <.input field={@cv_form[:headline]} label={gettext("Headline")} />
          <.input
            field={@cv_form[:years_experience]}
            type="number"
            label={gettext("Years of experience")}
          />
          <div class="sm:col-span-2">
            <.input field={@cv_form[:skills]} label={gettext("Skills (comma separated)")} />
          </div>
          <div class="sm:col-span-2">
            <.input
              field={@cv_form[:experiences]}
              type="textarea"
              label={gettext("Experiences, one per line: Company | Role | 2020-2023 | Summary")}
            />
          </div>
          <div class="sm:col-span-2">
            <.input field={@cv_form[:raw_text]} type="textarea" label={gettext("Full CV text")} />
          </div>
          <.input field={@cv_form[:age]} type="number" label={gettext("Age (protected criterion)")} />
          <.input field={@cv_form[:family_status]} label={gettext("Family situation (protected)")} />
          <.input field={@cv_form[:origin]} label={gettext("Origin (protected)")} />
        </.form>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <.button type="button" phx-click="submit" id="submit-application">
          {gettext("Send the application")}
        </.button>
        <p class="font-mono text-xs text-muted-foreground">
          {gettext("Uses the position and the CV as currently filled in.")}
        </p>
      </div>
    </div>
    """
  end

  defp pipeline(assigns) do
    assigns =
      assigns
      |> assign(:application, assigns.snapshot.application)
      |> assign(
        :state,
        View.state(assigns.events) || to_string(assigns.snapshot.application.state)
      )
      |> assign(:messages, View.messages(assigns.events))

    ~H"""
    <div class="grid gap-6 lg:grid-cols-3">
      <div class="space-y-6 lg:col-span-2">
        <div class="flex flex-wrap items-center gap-2">
          <h2 class="text-lg font-bold">{@snapshot.cv.name}</h2>
          <.tag text={View.state_label(@state)} />
          <.tag :if={@replay} text={gettext("replay")} variant="outline" />
        </div>

        <div class="grid gap-3 sm:grid-cols-2">
          <.agent_card
            :for={agent <- View.agents()}
            card={View.agent_card(@events, agent)}
            application={@application}
            threshold={@threshold}
          />
        </div>

        <.section :if={@messages != []}>
          <h3 class="text-sm font-bold">{gettext("Messages between agents")}</h3>
          <ul class="space-y-1 font-mono text-xs">
            <li :for={message <- @messages}>
              <span class="font-semibold">{View.agent_name(message.from)} → {View.agent_name(message.to)}</span>: {message.text}
            </li>
          </ul>
        </.section>

        <div :if={!@replay} class="space-y-6">
          <.section :if={@application.state == :manual_review} class="rounded border p-4">
            <h3 class="text-sm font-bold">{gettext("Manual review")}</h3>
            <p class="text-sm">
              {gettext(
                "Triage classified this document as \"%{category}\" with a confidence of %{confidence} (threshold %{threshold}). An ambiguous or suspicious case is never rejected automatically: you decide.",
                category: View.category_label(@application.triage_category),
                confidence:
                  :erlang.float_to_binary((@application.triage_confidence || 0) * 1.0, decimals: 2),
                threshold: :erlang.float_to_binary(@threshold * 1.0, decimals: 2)
              )}
            </p>
            <div class="flex gap-2">
              <.button phx-click="review" phx-value-approve="true">{gettext("Continue the screening")}</.button>
              <.button
                phx-click="review"
                phx-value-approve="false"
                class="bg-white !text-zinc-900 border hover:!bg-secondary"
              >
                {gettext("Reject")}
              </.button>
            </div>
          </.section>

          <.section
            :if={
              @snapshot.assessment &&
                @application.state in [:awaiting_decision, :drafting, :draft_ready, :sent, :rejected]
            }
            class="rounded border p-4"
          >
            <.report assessment={@snapshot.assessment} />
            <div :if={@application.state == :awaiting_decision} class="space-y-2 border-t pt-3">
              <p class="text-sm font-semibold">{gettext("Send an email to this candidate?")}</p>
              <div class="flex gap-2">
                <.button phx-click="decide" phx-value-decision="yes" id="decide-yes">{gettext("Yes")}</.button>
                <.button
                  phx-click="decide"
                  phx-value-decision="no"
                  id="decide-no"
                  class="bg-white !text-zinc-900 border hover:!bg-secondary"
                >
                  {gettext("No")}
                </.button>
              </div>
            </div>
          </.section>

          <.section :if={@application.state == :drafting} class="rounded border p-4">
            <p class="text-sm">
              <.icon name="hero-arrow-path" class="h-3 w-3 animate-spin" /> {gettext(
                "The Writer is drafting the email…"
              )}
            </p>
          </.section>

          <.section :if={@application.state == :draft_ready && @draft_form} class="rounded border p-4">
            <h3 class="text-sm font-bold">{gettext("Draft")}</h3>
            <p class="font-mono text-xs text-muted-foreground">
              {gettext("Written by the Writer agent. Edit it freely: only you can send it.")}
            </p>
            <.form
              for={@draft_form}
              id="draft-form"
              phx-change="draft_change"
              phx-submit="send_email"
              class="space-y-3"
            >
              <.input field={@draft_form[:subject]} label={gettext("Subject")} />
              <.input field={@draft_form[:body]} type="textarea" label={gettext("Body")} rows="12" />
              <div>
                <p class="text-xs font-semibold">
                  {gettext("Changes compared with the agent's version")}
                </p>
                <.diff lines={View.diff(agent_draft(@snapshot.drafts), @draft_form.params)} />
              </div>
              <.button type="submit" id="send-email">{gettext("Send the email")}</.button>
            </.form>
          </.section>

          <.section :if={@snapshot.outbox != []} class="rounded border p-4">
            <h3 class="text-sm font-bold">{gettext("Outbox (fake: nothing leaves this page)")}</h3>
            <.outbox emails={@snapshot.outbox} />
          </.section>

          <.section :if={@application.state == :failed} class="rounded border border-destructive p-4">
            <h3 class="text-sm font-bold">{gettext("The pipeline failed")}</h3>
            <p class="font-mono text-xs">{@application.failure_reason}</p>
          </.section>
        </div>
      </div>

      <aside class="lg:col-span-1">
        <.journal
          events={@events}
          integrity={@integrity}
          replaying={@replay != nil}
          export_path={application_path(@locale, @application.id) <> "/journal.json"}
        />
      </aside>
    </div>
    """
  end

  defp agent_draft(drafts) do
    draft = Enum.find(drafts, &(&1.author_kind == :agent)) || hd(drafts)
    %{"subject" => draft.subject, "body" => draft.body}
  end

  defp template_label("aligned"), do: gettext("Aligned profile")
  defp template_label("partial"), do: gettext("Partial profile")
  defp template_label("off_topic"), do: gettext("Off-topic document")
  defp template_label("injection"), do: gettext("Prompt injection")
  defp template_label("protected"), do: gettext("Protected criteria")
  defp template_label("inconsistent"), do: gettext("Inconsistency")
  defp template_label(other), do: other
end
