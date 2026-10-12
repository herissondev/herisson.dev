defmodule Portfolio.RecruitingDemo.Changes.Audit do
  @moduledoc """
  Emits a business `AuditEvent` once the action succeeded.

  Options:
    * `:type` - event type
    * `:fields` - attributes of the result and arguments to put in the payload
  """
  use Ash.Resource.Change

  alias Portfolio.RecruitingDemo.AuditLog

  @impl true
  def change(changeset, opts, %{actor: actor}) do
    Ash.Changeset.after_action(changeset, fn changeset, result ->
      payload =
        Map.new(opts[:fields] || [], fn field ->
          {field, Ash.Changeset.get_argument(changeset, field) || Map.get(result, field)}
        end)

      {:ok, _} =
        AuditLog.append(%{
          application_id: application_id(result),
          actor: actor,
          type: opts[:type],
          payload: payload
        })

      {:ok, result}
    end)
  end

  @doc false
  def application_id(%Portfolio.RecruitingDemo.Resources.Application{id: id}), do: id
  def application_id(%{application_id: id}), do: id
end
