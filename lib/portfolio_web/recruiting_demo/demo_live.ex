defmodule PortfolioWeb.RecruitingDemo.DemoLive do
  @moduledoc """
  The visitor plays the recruiter: picks a candidate (and may edit the
  position or the CV), watches the agents step by step, then alone decides
  and sends the email. Mobile first: one column, details folded.
  """
  use PortfolioWeb, :live_view

  import PortfolioWeb.MainComponents, only: [tag: 1]
  import PortfolioWeb.RecruitingDemo.Components

  alias Portfolio.RecruitingDemo
  alias PortfolioWeb.RecruitingDemo.{Forms, View}

  @replay_tick_ms 300

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: RecruitingDemo.subscribe(socket.assigns.session_id)

    locale = socket.assigns.locale
    templates = RecruitingDemo.cv_templates(locale)

    {:ok,
     socket
     |> assign(:page_title, gettext("Recruiting demo"))
     |> assign(:templates, templates)
     |> assign(
       :offer_form,
       to_form(Forms.offer_params(RecruitingDemo.default_offer(locale)), as: :offer)
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
  def handle_event("offer_change", %{"offer" => params}, socket),
    do: {:noreply, assign(socket, :offer_form, to_form(params, as: :offer))}

  def handle_event("cv_change", %{"cv" => params}, socket),
    do: {:noreply, assign(socket, :cv_form, to_form(params, as: :cv))}

  def handle_event("pick_cv", %{"template" => template_id}, socket) do
    case Enum.find(socket.assigns.templates, &(&1.template_id == template_id)) do
      nil -> {:noreply, socket}
      cv -> {:noreply, assign(socket, :cv_form, to_form(Forms.cv_params(cv), as: :cv))}
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
    <main class="container mx-auto px-4 py-6 md:py-10">
      <div class="mx-auto w-full max-w-2xl space-y-6 bg-white">
        <header class="space-y-2">
          <h1 class="text-2xl font-bold leading-tight">
            {gettext("Hiring with AI agents, under control")}
          </h1>
          <p class="text-pretty text-sm text-muted-foreground">
            {gettext(
              "You are hiring a salesperson. Four AI agents sort, check and analyse the application. Each one can only do what its role allows, and you alone decide to send the email."
            )}
          </p>
          <div class="flex flex-wrap gap-1.5">
            <.tag text={gettext("Fictitious data")} variant="secondary" />
            <.tag text={gettext("Nothing is kept")} variant="secondary" />
            <.tag text={gettext("Simulated web research")} variant="secondary" />
          </div>
        </header>

        <.new_application :if={@live_action == :new} {assigns} />
        <.pipeline :if={@live_action == :show && @snapshot} {assigns} />
      </div>
    </main>

    <.modal :if={@context_agent} id="agent-context" show on_cancel={close_context()}>
      <h2 class="text-lg font-bold">
        {gettext("Context received by %{agent}", agent: View.agent_name(@context_agent))}
      </h2>
      <p class="text-xs text-muted-foreground">
        {gettext("Exactly what was sent to the model, as recorded in the journal.")}
      </p>
      <pre
        :for={event <- View.agent_card(@events, @context_agent).inputs}
        class="mt-3 max-h-96 overflow-auto whitespace-pre-wrap break-words rounded border p-2 font-mono text-[11px]"
      >{View.pretty(event.payload["input"])}</pre>
    </.modal>
    """
  end

  defp new_application(assigns) do
    assigns = assign(assigns, :offer, assigns.offer_form.params)

    ~H"""
    <div class="space-y-6">
      <ol class="flex flex-wrap gap-x-4 gap-y-1 text-sm">
        <li><span class="font-bold">1.</span> {gettext("Pick a candidate")}</li>
        <li><span class="font-bold">2.</span> {gettext("Watch the AI agents work")}</li>
        <li><span class="font-bold">3.</span> {gettext("You decide, you send")}</li>
      </ol>

      <section class="space-y-2">
        <h2 class="text-sm font-bold">{gettext("The position")}</h2>
        <details class="rounded border p-3">
          <summary class="cursor-pointer list-none">
            <p class="font-semibold">{@offer["title"]}</p>
            <p class="text-sm text-muted-foreground">
              {@offer["location"]} · {gettext("%{min}–%{max} k€/year",
                min: thousands(@offer["salary_min"]),
                max: thousands(@offer["salary_max"])
              )} · {gettext("%{years} years min.", years: @offer["min_years"])}
            </p>
            <p class="mt-1 text-xs font-semibold underline">{gettext("Edit the position")}</p>
          </summary>
          <.form
            for={@offer_form}
            id="offer-form"
            phx-change="offer_change"
            class="mt-3 grid gap-3 sm:grid-cols-2"
          >
            <div class="sm:col-span-2">
              <.input field={@offer_form[:title]} label={gettext("Job title")} />
            </div>
            <.input
              field={@offer_form[:salary_min]}
              type="number"
              label={gettext("Salary min (€/year)")}
            />
            <.input
              field={@offer_form[:salary_max]}
              type="number"
              label={gettext("Salary max (€/year)")}
            />
            <.input
              field={@offer_form[:min_years]}
              type="number"
              label={gettext("Minimum years of experience")}
            />
            <.input field={@offer_form[:location]} label={gettext("Location")} />
            <div class="sm:col-span-2">
              <.input
                field={@offer_form[:required_skills]}
                label={gettext("Required skills (comma separated)")}
              />
            </div>
            <div class="sm:col-span-2">
              <.input
                field={@offer_form[:nice_to_have_skills]}
                label={gettext("Nice to have (comma separated)")}
              />
            </div>
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
        </details>
      </section>

      <section class="space-y-2">
        <h2 class="text-sm font-bold">{gettext("Pick a candidate")}</h2>
        <div class="grid gap-2 sm:grid-cols-2">
          <button
            :for={cv <- @templates}
            type="button"
            id={"pick-#{cv.template_id}"}
            phx-click="pick_cv"
            phx-value-template={cv.template_id}
            class={[
              "rounded border p-3 text-left transition-colors hover:bg-secondary",
              @cv_form.params["template_id"] == cv.template_id &&
                "border-zinc-900 ring-1 ring-zinc-900"
            ]}
          >
            <span class="block font-semibold">{cv.name}</span>
            <span class="mt-1 block text-sm text-muted-foreground">{template_pitch(cv.template_id)}</span>
          </button>
        </div>

        <details class="rounded border p-3">
          <summary class="cursor-pointer list-none text-xs font-semibold underline">
            {gettext("Edit this CV (%{name})", name: @cv_form.params["name"])}
          </summary>
          <.form
            for={@cv_form}
            id="cv-form"
            phx-change="cv_change"
            class="mt-3 grid gap-3 sm:grid-cols-2"
          >
            <input type="hidden" name="cv[template_id]" value={@cv_form.params["template_id"]} />
            <.input field={@cv_form[:name]} label={gettext("Name")} />
            <.input field={@cv_form[:email]} label={gettext("Email")} />
            <div class="sm:col-span-2">
              <.input field={@cv_form[:headline]} label={gettext("Headline")} />
            </div>
            <.input
              field={@cv_form[:years_experience]}
              type="number"
              label={gettext("Years of experience")}
            />
            <.input field={@cv_form[:skills]} label={gettext("Skills (comma separated)")} />
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
        </details>
      </section>

      <.button type="button" phx-click="submit" id="submit-application" class="w-full py-3 text-base">
        {gettext("Start the analysis")}
      </.button>

      <nav :if={@applications != []} class="space-y-1 text-sm">
        <p class="font-semibold">{gettext("Your previous applications")}</p>
        <.link
          :for={application <- @applications}
          patch={application_path(@locale, application.id)}
          class="block underline"
        >
          {application.cv_submission.name} · {View.state_label(to_string(application.state))}
        </.link>
      </nav>
    </div>
    """
  end

  defp pipeline(assigns) do
    application = assigns.snapshot.application
    steps = View.steps(assigns.events)

    assigns =
      assigns
      |> assign(:application, application)
      |> assign(:steps, steps)
      |> assign(:state, View.state(assigns.events) || to_string(application.state))
      |> assign(:messages, View.messages(assigns.events))
      |> assign(:refusals, View.refusals(assigns.events))

    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div class="min-w-0">
          <p class="text-xs text-muted-foreground">{@snapshot.offer.title}</p>
          <h2 class="text-lg font-bold">{@snapshot.cv.name}</h2>
        </div>
        <.link patch={base_path(@locale)} class="text-sm font-semibold underline">
          ← {gettext("Another candidate")}
        </.link>
      </div>

      <p :if={@replay} class="rounded bg-secondary px-3 py-2 text-sm">
        <.icon name="hero-play-mini" class="h-4 w-4" /> {gettext("Replaying from the journal…")}
      </p>

      <ol class="list-none">
        <.step
          :for={{step, index} <- Enum.with_index(@steps, 1)}
          step={step}
          index={index}
          last={index == length(@steps)}
        >
          <.step_body step={step} {assigns} />
        </.step>
      </ol>

      <.journal
        events={@events}
        integrity={@integrity}
        replaying={@replay != nil}
        export_path={application_path(@locale, @application.id) <> "/journal.json"}
      />
    </div>
    """
  end

  # What appears under a step: actions when it waits for you, details otherwise
  defp step_body(%{step: %{key: :triage}} = assigns) do
    ~H"""
    <div :if={!@replay && @application.state == :manual_review} class="space-y-2 rounded border p-3">
      <p :if={@application.triage_category == :suspect} class="text-sm">
        {gettext(
          "The sorting AI found suspicious content: instructions addressed to an AI are hidden in this CV. As a precaution, you decide whether the analysis goes on."
        )}
      </p>
      <p :if={@application.triage_category != :suspect} class="text-sm">
        {gettext(
          "The sorting AI is not sure about this document (%{category}, confidence %{confidence}%, threshold %{threshold}%). It never rejects an unclear case on its own.",
          category: View.category_label(@application.triage_category),
          confidence: round((@application.triage_confidence || 0) * 100),
          threshold: round(@threshold * 100)
        )}
      </p>
      <div class="flex flex-col gap-2 sm:flex-row">
        <.button phx-click="review" phx-value-approve="true" class="w-full sm:w-auto">
          {gettext("Continue anyway")}
        </.button>
        <button phx-click="review" phx-value-approve="false" class={secondary_button()}>
          {gettext("Reject")}
        </button>
      </div>
    </div>
    <.refusals refusals={agent_refusals(@refusals, "triage")} />
    <.agent_rights agent="triage" runs={View.agent_card(@events, "triage").runs} />
    """
  end

  defp step_body(%{step: %{key: :research}} = assigns) do
    ~H"""
    <.refusals refusals={agent_refusals(@refusals, "researcher")} />
    <.agent_rights
      :if={@step.status in [:running, :done, :failed]}
      agent="researcher"
      runs={View.agent_card(@events, "researcher").runs}
    />
    """
  end

  defp step_body(%{step: %{key: :analysis}} = assigns) do
    ~H"""
    <ul :if={@messages != []} class="space-y-1 text-sm">
      <li :for={message <- @messages} class="rounded bg-secondary px-3 py-2">
        <span class="font-semibold">{View.agent_name(message.from)} → {View.agent_name(message.to)} :</span>
        {message.text}
      </li>
    </ul>
    <.refusals refusals={agent_refusals(@refusals, "matcher")} />
    <.agent_rights
      :if={@step.status in [:running, :done, :failed]}
      agent="matcher"
      runs={View.agent_card(@events, "matcher").runs}
    />
    """
  end

  defp step_body(%{step: %{key: :decision}} = assigns) do
    ~H"""
    <div :if={!@replay && @snapshot.assessment && @step.status in [:action, :done]} class="space-y-3">
      <.report :if={@step.status == :action} assessment={@snapshot.assessment} />
      <details :if={@step.status == :done}>
        <summary class="cursor-pointer text-xs font-semibold underline">
          {gettext("See the AI's opinion again")}
        </summary>
        <div class="mt-2"><.report assessment={@snapshot.assessment} /></div>
      </details>
      <div :if={@application.state == :awaiting_decision} class="space-y-2">
        <p class="text-sm font-semibold">{gettext("Send an email to this candidate?")}</p>
        <div class="flex flex-col gap-2 sm:flex-row">
          <.button
            phx-click="decide"
            phx-value-decision="yes"
            id="decide-yes"
            class="w-full sm:w-auto"
          >
            {gettext("Yes, draft the email")}
          </.button>
          <button phx-click="decide" phx-value-decision="no" id="decide-no" class={secondary_button()}>
            {gettext("No")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp step_body(%{step: %{key: :writing}} = assigns) do
    ~H"""
    <.refusals refusals={agent_refusals(@refusals, "writer")} />
    <.agent_rights
      :if={@step.status in [:running, :done, :failed]}
      agent="writer"
      runs={View.agent_card(@events, "writer").runs}
    />
    """
  end

  defp step_body(%{step: %{key: :sending}} = assigns) do
    ~H"""
    <.form
      :if={!@replay && @application.state == :draft_ready && @draft_form}
      for={@draft_form}
      id="draft-form"
      phx-change="draft_change"
      phx-submit="send_email"
      class="space-y-3"
    >
      <p class="text-xs text-muted-foreground">
        {gettext("Written by the AI. Edit it freely: only you can send it.")}
      </p>
      <.input field={@draft_form[:subject]} label={gettext("Subject")} />
      <.input field={@draft_form[:body]} type="textarea" label={gettext("Body")} rows="12" />
      <.button type="submit" id="send-email" class="w-full sm:w-auto">{gettext("Send the email")}</.button>
    </.form>
    <div :if={@snapshot.outbox != []} class="space-y-2">
      <p class="text-xs text-muted-foreground">{gettext("Fake outbox: nothing leaves this page.")}</p>
      <.outbox emails={@snapshot.outbox} />
    </div>
    <p :if={@application.state == :failed} class="text-sm text-destructive">
      {gettext("The analysis failed:")} {@application.failure_reason}
    </p>
    """
  end

  defp thousands(value) do
    case Integer.parse(to_string(value)) do
      {amount, _} -> div(amount, 1000)
      :error -> value
    end
  end

  defp agent_refusals(refusals, agent), do: Enum.filter(refusals, &(&1.actor_role == agent))

  defp secondary_button,
    do: "w-full rounded-lg border px-3 py-2 text-sm font-semibold hover:bg-secondary sm:w-auto"

  defp template_pitch("aligned"), do: gettext("Good profile: goes through every step.")
  defp template_pitch("partial"), do: gettext("Half a match: the AI does not decide alone.")
  defp template_pitch("off_topic"), do: gettext("Not a CV at all: rejected at sorting.")
  defp template_pitch("injection"), do: gettext("Hides an order addressed to the AI.")
  defp template_pitch("protected"), do: gettext("States age and origin: the AI never sees them.")

  defp template_pitch("inconsistent"),
    do: gettext("Claims a company nobody can find: the AI checks.")

  defp template_pitch(_other), do: ""
end
