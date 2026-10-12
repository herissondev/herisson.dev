defmodule Portfolio.RecruitingDemo.Validations.ApplicationInState do
  @moduledoc "The related application must currently be in one of `:states`."
  use Ash.Resource.Validation

  alias Portfolio.RecruitingDemo.Resources.Application

  @impl true
  def validate(changeset, opts, _context) do
    application_id = Ash.Changeset.get_attribute(changeset, :application_id)

    case application_id && Ash.get(Application, application_id, authorize?: false) do
      {:ok, %{state: state}} ->
        if state in opts[:states],
          do: :ok,
          else:
            {:error,
             field: :application_id,
             message: "application is #{state}, expected #{inspect(opts[:states])}"}

      _ ->
        {:error, field: :application_id, message: "application not found"}
    end
  end
end
