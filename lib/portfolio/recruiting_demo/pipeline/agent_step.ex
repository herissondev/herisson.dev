defmodule Portfolio.RecruitingDemo.Pipeline.AgentStep do
  @moduledoc """
  Calls an agent's model (with a timeout and a bounded number of attempts),
  then runs the tool calls it asked for, as the agent's actor.

  If the model keeps failing, the compensation marks the application
  `failed`; the middleware journals `step_failed` then `compensated`.
  """
  use Reactor.Step

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Actor
  alias Portfolio.RecruitingDemo.Agents.Tools
  alias Portfolio.RecruitingDemo.Pipeline

  @impl true
  def run(%{input: input} = arguments, context, options) do
    agent = options[:agent] || Map.fetch!(arguments, :agent)
    role = agent.role()
    actor = Actor.agent(role, context.session_id)
    started = System.monotonic_time(:millisecond)

    case call(role, input, context, attempts(), 1) do
      {:ok, response, attempt} ->
        tool_calls =
          Enum.map(response.tool_calls, &Tools.execute(&1, actor, context.application_id))

        {:ok,
         %{
           agent: role,
           output: response.output,
           tool_calls: tool_calls,
           model: response.model,
           usage: response.usage,
           attempts: attempt,
           latency_ms: System.monotonic_time(:millisecond) - started,
           process: inspect(self())
         }}

      {:error, reason, attempt} ->
        {:error, Pipeline.StepError.exception(agent: role, reason: reason, attempts: attempt)}
    end
  end

  @impl true
  def compensate(error, _arguments, context, _options) do
    Pipeline.fail(context.application_id, context.session_id, Pipeline.root_cause(error))
    :ok
  end

  defp call(role, input, context, max, attempt) do
    task =
      Task.Supervisor.async_nolink(RecruitingDemo.TaskSupervisor, fn ->
        backend(context).call(role, input, context)
      end)

    result =
      case Task.yield(task, timeout()) || Task.shutdown(task, :brutal_kill) do
        {:ok, %{} = response} -> {:ok, response}
        {:ok, {:error, reason}} -> {:error, reason}
        {:exit, reason} -> {:error, {:crashed, reason}}
        nil -> {:error, :timeout}
      end

    case result do
      {:ok, response} -> {:ok, response, attempt}
      {:error, _reason} when attempt < max -> call(role, input, context, max, attempt + 1)
      {:error, reason} -> {:error, reason, attempt}
    end
  end

  # A run may impose its backend (forced calls); :auto picks the real models
  # when an OpenRouter key is configured
  defp backend(%{backend: backend}) when is_atom(backend) and not is_nil(backend), do: backend

  defp backend(_context) do
    case Keyword.get(RecruitingDemo.config(), :agent_backend, :auto) do
      :auto ->
        if RecruitingDemo.Agents.Live.available?(),
          do: RecruitingDemo.Agents.Live,
          else: RecruitingDemo.Agents.Simulated

      backend ->
        backend
    end
  end

  defp timeout, do: Keyword.get(RecruitingDemo.config(), :agent_timeout_ms, 30_000)
  defp attempts, do: Keyword.get(RecruitingDemo.config(), :agent_attempts, 2)
end
