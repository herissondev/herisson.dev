defmodule Portfolio.RecruitingDemo.Pipeline.InputStep do
  @moduledoc """
  Builds an agent's input, reading as that agent. Kept as its own step so
  the agent step starts with exactly what the model receives (journaled as
  `agent_input` by the middleware).
  """
  use Reactor.Step

  alias Portfolio.RecruitingDemo.Actor

  @impl true
  def run(arguments, context, options) do
    agent = Keyword.fetch!(options, :agent)
    args = Map.get(arguments, :args, arguments)
    actor = Actor.agent(agent.role(), context.session_id)

    {:ok, agent.input(args.application_id, actor, Map.put(args, :locale, context[:locale]))}
  end
end
