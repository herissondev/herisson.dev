defmodule Portfolio.RecruitingDemo.Changes.AuditTransition do
  @moduledoc "Emits a `state_transition` event when an Application changes state."
  use Ash.Resource.Change

  alias Portfolio.RecruitingDemo.AuditLog

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    from = if changeset.action_type == :create, do: nil, else: changeset.data.state

    Ash.Changeset.after_action(changeset, fn _changeset, result ->
      if from != result.state do
        {:ok, _} =
          AuditLog.append(%{
            application_id: result.id,
            actor: actor,
            type: :state_transition,
            payload: %{from: from, to: result.state}
          })
      end

      {:ok, result}
    end)
  end
end
