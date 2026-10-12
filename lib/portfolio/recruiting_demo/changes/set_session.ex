defmodule Portfolio.RecruitingDemo.Changes.SetSession do
  @moduledoc """
  Stamps a new record with the actor's session id, so nobody can create
  data in another visitor's session.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, %{actor: %{session_id: session_id}}),
    do: Ash.Changeset.force_change_attribute(changeset, :session_id, session_id)

  def change(changeset, _opts, _context),
    do: Ash.Changeset.add_error(changeset, field: :session_id, message: "requires an actor")
end
