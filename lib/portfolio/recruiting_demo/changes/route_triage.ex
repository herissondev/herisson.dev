defmodule Portfolio.RecruitingDemo.Changes.RouteTriage do
  @moduledoc """
  Picks the state after triage. Below the confidence threshold, or when the
  document looks suspicious, the visitor reviews it instead of a rejection.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    category = Ash.Changeset.get_attribute(changeset, :triage_category)
    confidence = Ash.Changeset.get_attribute(changeset, :triage_confidence) || 0.0

    AshStateMachine.transition_state(changeset, target(category, confidence))
  end

  def threshold, do: Keyword.get(Portfolio.RecruitingDemo.config(), :triage_threshold, 0.7)

  def target(category, confidence) do
    cond do
      confidence < threshold() -> :manual_review
      category == :relevant -> :researching
      category in [:off_position, :unrelated] -> :rejected
      true -> :manual_review
    end
  end
end
