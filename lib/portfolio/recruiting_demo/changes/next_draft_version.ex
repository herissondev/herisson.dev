defmodule Portfolio.RecruitingDemo.Changes.NextDraftVersion do
  @moduledoc """
  Numbers a human edit after the latest draft and emits `draft_edited`
  with the line diff between the two versions.
  """
  use Ash.Resource.Change

  require Ash.Query

  alias Portfolio.RecruitingDemo.AuditLog
  alias Portfolio.RecruitingDemo.Resources.EmailDraft

  # Hooks run only once the action is authorized
  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      previous = latest(Ash.Changeset.get_attribute(changeset, :application_id))

      changeset
      |> Ash.Changeset.force_change_attribute(:version, ((previous && previous.version) || 0) + 1)
      |> Ash.Changeset.put_context(:previous_draft, previous)
    end)
    |> Ash.Changeset.after_action(fn changeset, draft ->
      previous = changeset.context.previous_draft

      {:ok, _} =
        AuditLog.append(%{
          application_id: draft.application_id,
          actor: actor,
          type: :draft_edited,
          payload: %{
            from_version: previous && previous.version,
            to_version: draft.version,
            diff: diff(previous, draft)
          }
        })

      {:ok, draft}
    end)
  end

  defp latest(application_id) do
    EmailDraft
    |> Ash.Query.filter(application_id == ^application_id)
    |> Ash.Query.sort(version: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  @doc "Line diff between two drafts, as `[[op, line]]` with op in eq/del/ins."
  def diff(nil, new), do: diff(%{subject: "", body: ""}, new)

  def diff(old, new) do
    lines = fn draft -> ["Subject: " <> draft.subject | String.split(draft.body, "\n")] end

    lines.(old)
    |> List.myers_difference(lines.(new))
    |> Enum.flat_map(fn {op, chunk} -> Enum.map(chunk, &[op, &1]) end)
  end
end
