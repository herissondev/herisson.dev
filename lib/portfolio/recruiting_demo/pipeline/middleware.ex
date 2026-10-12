defmodule Portfolio.RecruitingDemo.Pipeline.Middleware do
  @moduledoc """
  Journals the orchestration side of every Reactor: what each agent
  received and returned, refused tool calls, failed steps and their
  compensation. Business facts are journaled by Ash changes instead.
  """
  use Reactor.Middleware

  alias Portfolio.RecruitingDemo.{Actor, AuditLog}
  alias Portfolio.RecruitingDemo.Pipeline.AgentStep

  @impl true
  def event({:run_start, %{input: input} = arguments}, %{impl: {AgentStep, opts}}, context) do
    role = (opts[:agent] || arguments[:agent]).role()

    append(context, Actor.agent(role, context.session_id), :agent_input, %{
      agent: role,
      input: input
    })
  end

  def event({:run_complete, result}, %{impl: {AgentStep, _opts}}, context) do
    actor = Actor.agent(result.agent, context.session_id)

    append(context, actor, :agent_output, %{
      agent: result.agent,
      output: result.output,
      model: result.model,
      usage: result.usage,
      latency_ms: result.latency_ms,
      attempts: result.attempts,
      process: result.process,
      tool_calls: Enum.map(result.tool_calls, &Map.take(&1, [:tool, :status, :reason]))
    })

    for %{status: status} = call <- result.tool_calls, status in [:denied, :unknown] do
      append(context, actor, :tool_denied, %{
        tool: call.tool,
        args: call.args,
        actor: Actor.label(actor),
        reason: call.reason
      })
    end

    :ok
  end

  def event({:run_error, error}, step, context) do
    append(context, Actor.system(context.session_id), :step_failed, %{
      step: inspect(step.name),
      error: Portfolio.RecruitingDemo.Pipeline.root_cause(error)
    })
  end

  def event(:compensate_complete, step, context) do
    append(context, Actor.system(context.session_id), :compensated, %{
      step: inspect(step.name),
      action: "application marked failed"
    })
  end

  def event(_event, _step, _context), do: :ok

  defp append(context, actor, type, payload) do
    {:ok, _} =
      AuditLog.append(%{
        application_id: context.application_id,
        actor: actor,
        type: type,
        payload: payload
      })

    :ok
  end
end
