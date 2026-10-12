defmodule Portfolio.RecruitingDemo.Pipeline do
  @moduledoc """
  Starts the Reactors under the demo's Task.Supervisor, so a crash never
  reaches the CV pages. Each run gets `application_id`, `session_id` and
  `locale` as context.
  """

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Actor
  alias Portfolio.RecruitingDemo.Agents

  alias Portfolio.RecruitingDemo.Pipeline.{
    DraftingReactor,
    ForcedCallReactor,
    MatchingReactor,
    ScreeningReactor
  }

  alias Portfolio.RecruitingDemo.Resources.Application

  @context_keys [:application_id, :session_id, :locale, :backend]

  @agents %{
    "triage" => Agents.Triage,
    "researcher" => Agents.Researcher,
    "matcher" => Agents.Matcher,
    "writer" => Agents.Writer
  }

  def screen(application, opts \\ []), do: start(ScreeningReactor, application, opts)
  def resume_matching(application, opts \\ []), do: start(MatchingReactor, application, opts)
  def draft(application, opts \\ []), do: start(DraftingReactor, application, opts)

  @doc """
  Makes an agent call `send_email` on purpose, through the very same steps
  and journal as a real run: the policy must refuse it. The application's
  state is left untouched whatever happens.
  """
  def force_forbidden_call(application, agent, opts \\ []) when is_map_key(@agents, agent) do
    context = %{
      application_id: application.id,
      session_id: application.session_id,
      locale: opts[:locale] || "en",
      backend: Agents.Forced
    }

    run = fn ->
      Reactor.run(
        ForcedCallReactor,
        %{application_id: application.id, agent: @agents[agent]},
        context
      )
    end

    if Keyword.get(opts, :async?, true) do
      {:ok, _pid} = Task.Supervisor.start_child(RecruitingDemo.TaskSupervisor, run)
      :ok
    else
      run.()
    end
  end

  defp start(reactor, application, opts) do
    context = %{
      application_id: application.id,
      session_id: application.session_id,
      locale: opts[:locale] || "en"
    }

    if Keyword.get(opts, :async?, true) do
      {:ok, _pid} =
        Task.Supervisor.start_child(RecruitingDemo.TaskSupervisor, fn -> run(reactor, context) end)

      :ok
    else
      run(reactor, context)
    end
  end

  @doc "Runs a Reactor; whatever went wrong, the application does not stay in an automatic state."
  def run(reactor, context) do
    case Reactor.run(reactor, %{application_id: context.application_id}, context,
           max_concurrency: 4
         ) do
      {:ok, result} ->
        {:ok, result}

      {:error, error} ->
        fail(context.application_id, context.session_id, root_cause(error))
        {:error, error}
    end
  end

  @doc "The innermost error message, under the layers of Reactor and Ash wrapping."
  def root_cause(%{errors: [error | _]}), do: root_cause(error)
  def root_cause(%{error: error}) when not is_nil(error), do: root_cause(error)
  def root_cause(error) when is_exception(error), do: Exception.message(error)
  def root_cause(error) when is_binary(error), do: error
  def root_cause(error), do: inspect(error)

  @doc "Runs a sub-Reactor from inside a step, with the same demo context."
  def run_sub(reactor, context, inputs \\ %{}) do
    context = Map.take(context, @context_keys)
    Reactor.run(reactor, Map.put(inputs, :application_id, context.application_id), context)
  end

  @doc "A state transition by the orchestrator."
  def transition(context, action) do
    actor = Actor.system(context.session_id)

    with {:ok, application} <- Ash.get(Application, context.application_id, actor: actor) do
      application |> Ash.Changeset.for_update(action, %{}, actor: actor) |> Ash.update()
    end
  end

  @doc "Marks the application `failed` if it is still in an automatic state."
  def fail(application_id, session_id, reason) do
    actor = Actor.system(session_id)

    with {:ok, %{state: state} = application} <-
           Ash.get(Application, application_id, actor: actor),
         true <- state in Application.automatic_states() do
      application
      |> Ash.Changeset.for_update(:fail, %{failure_reason: String.slice(reason, 0, 500)},
        actor: actor
      )
      |> Ash.update()
    end
  end
end
