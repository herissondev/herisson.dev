defmodule Portfolio.RecruitingDemo.Validations.SameSession do
  @moduledoc """
  The record referenced by `:attribute` must be readable by the actor,
  i.e. belong to the actor's session (read policies filter the rest out).
  """
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, opts, %{actor: actor}) do
    case Ash.Changeset.get_attribute(changeset, opts[:attribute]) do
      nil ->
        :ok

      id ->
        case Ash.get(opts[:resource], id, actor: actor, authorize?: false) do
          {:ok, %{session_id: session_id}} when session_id == actor.session_id ->
            :ok

          _ ->
            {:error, field: opts[:attribute], message: "does not belong to this session"}
        end
    end
  end

  def validate(_changeset, opts, _context),
    do: {:error, field: opts[:attribute], message: "requires an actor"}
end
