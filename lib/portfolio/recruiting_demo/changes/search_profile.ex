defmodule Portfolio.RecruitingDemo.Changes.SearchProfile do
  @moduledoc """
  The simulated `search_profile` tool: findings come from the pre-written
  fixtures, never from the internet. The CV is read as the Researcher, so it
  only gets the name and declared experiences.
  """
  use Ash.Resource.Change

  alias Portfolio.RecruitingDemo.Catalog
  alias Portfolio.RecruitingDemo.Resources.{Application, CvSubmission}

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      application_id = Ash.Changeset.get_attribute(changeset, :application_id)
      topic = Ash.Changeset.get_attribute(changeset, :topic)
      query = Ash.Changeset.get_argument(changeset, :query)

      application = Ash.get!(Application, application_id, actor: actor)
      cv = Ash.get!(CvSubmission, application.cv_submission_id, actor: actor)

      changeset
      |> Ash.Changeset.force_change_attribute(:findings, findings(topic, cv, query))
      |> Ash.Changeset.force_change_attribute(:fixture_source, fixture_source(topic, cv))
    end)
  end

  def topics, do: ~w(experiences companies skills)

  def findings("experiences", cv, _query) do
    Enum.map(cv.experiences, fn exp ->
      known? = Catalog.company(exp.company) != nil

      %{
        claim: "#{exp.role} at #{exp.company} (#{period(exp)})",
        confirmed: known?,
        source: if(known?, do: "Professional network (simulated)", else: nil)
      }
    end)
  end

  def findings("companies", cv, _query) do
    cv.experiences |> Enum.map(& &1.company) |> Enum.uniq() |> Enum.map(&company_finding/1)
  end

  def findings("skills", cv, _query) do
    case Catalog.profile_findings(cv.template_id, "skills") do
      [] -> [%{claim: "No public profile found", confirmed: false, source: nil}]
      found -> found |> Enum.map(&Map.new(&1, fn {k, v} -> {String.to_existing_atom(k), v} end))
    end
  end

  # A verification question: re-check every declared company it mentions
  def findings("verification", cv, query) do
    query = String.downcase(query || "")

    cv.experiences
    |> Enum.map(& &1.company)
    |> Enum.uniq()
    |> Enum.filter(&String.contains?(query, String.downcase(&1)))
    |> case do
      [] -> [%{claim: "Nothing in the simulated sources answers this question", confirmed: false}]
      companies -> Enum.map(companies, &company_finding/1)
    end
  end

  defp company_finding(name) do
    case Catalog.company(name) do
      nil ->
        %{
          claim: "No public record of #{name}",
          confirmed: false,
          source: "Company register (simulated)"
        }

      %{"description" => description, "source" => source} ->
        %{claim: "#{name}: #{description}", confirmed: true, source: source}
    end
  end

  defp fixture_source("skills", cv), do: "research/profiles.json##{cv.template_id}"
  defp fixture_source(_topic, _cv), do: "research/companies.json"

  defp period(%{start_year: from, end_year: nil}), do: "since #{from}"
  defp period(%{start_year: from, end_year: to}), do: "#{from}-#{to}"
end
