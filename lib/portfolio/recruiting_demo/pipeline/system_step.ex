defmodule Portfolio.RecruitingDemo.Pipeline.SystemStep do
  @moduledoc "A state machine transition, performed by the orchestrator's actor."
  use Reactor.Step

  alias Portfolio.RecruitingDemo.Actor
  alias Portfolio.RecruitingDemo.Resources.Application

  @impl true
  def run(%{application_id: application_id}, context, options) do
    actor = Actor.system(context.session_id)

    with {:ok, application} <- Ash.get(Application, application_id, actor: actor) do
      application
      |> Ash.Changeset.for_update(Keyword.fetch!(options, :action), %{}, actor: actor)
      |> Ash.update()
    end
  end
end
