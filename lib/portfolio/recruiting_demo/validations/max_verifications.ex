defmodule Portfolio.RecruitingDemo.Validations.MaxVerifications do
  @moduledoc """
  Caps the Matcher ⇄ Researcher loop: an application gets at most `:max`
  research requests. This is the bound, not a prompt instruction.
  """
  use Ash.Resource.Validation

  require Ash.Query

  alias Portfolio.RecruitingDemo.Resources.ResearchRequest

  @impl true
  def validate(changeset, opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :application_id) do
      nil ->
        :ok

      application_id ->
        count =
          ResearchRequest
          |> Ash.Query.filter(application_id == ^application_id)
          |> Ash.count!(authorize?: false)

        if count < opts[:max],
          do: :ok,
          else: {:error, field: :question, message: "verification limit (#{opts[:max]}) reached"}
    end
  end
end
