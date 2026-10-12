defmodule Portfolio.RecruitingDemo.Changes.SendEmail do
  @moduledoc """
  Delivers the email to the fake outbox, as the same (human) actor. The
  outbox itself refuses anything that is not a human.
  """
  use Ash.Resource.Change

  alias Portfolio.RecruitingDemo.Resources.{CvSubmission, OutboxEmail}

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.after_action(changeset, fn changeset, application ->
      cv = Ash.get!(CvSubmission, application.cv_submission_id, actor: actor)

      OutboxEmail
      |> Ash.Changeset.for_create(
        :deliver,
        %{
          application_id: application.id,
          to: cv.email || cv.name,
          subject: Ash.Changeset.get_argument(changeset, :subject),
          body: Ash.Changeset.get_argument(changeset, :body)
        },
        actor: actor
      )
      |> Ash.create()
      |> case do
        {:ok, _email} -> {:ok, application}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
