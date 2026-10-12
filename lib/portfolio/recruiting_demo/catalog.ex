defmodule Portfolio.RecruitingDemo.Catalog do
  @moduledoc """
  Fictitious demo data from `priv/recruiting_demo/`, embedded at compile
  time. None of it relates to the real CV of the site.
  """

  @dir Path.expand("../../../priv/recruiting_demo", __DIR__)
  @files ~w(job_offer.json cvs.json research/companies.json research/profiles.json)

  for file <- @files, do: @external_resource(Path.join(@dir, file))

  read = fn file -> @dir |> Path.join(file) |> File.read!() |> Jason.decode!() end

  @job_offer read.("job_offer.json")
  @cvs read.("cvs.json")
  @companies Map.delete(read.("research/companies.json"), "_note")
  @profiles Map.delete(read.("research/profiles.json"), "_note")

  @doc "Default job offer, as attributes for `JobOffer.configure`."
  def job_offer, do: atomize(@job_offer)

  @doc "CV templates, classic ones first."
  def cvs, do: Enum.map(@cvs, &atomize/1)

  def cv(template_id), do: Enum.find(cvs(), &(&1.template_id == template_id))

  @doc "Attributes of a CV template for `CvSubmission.submit`."
  def cv_attributes(template_id), do: template_id |> cv() |> Map.delete(:kind)

  @doc "Simulated company register: `nil` when the company is unknown."
  def company(name), do: Map.get(@companies, name)

  @doc "Simulated public-profile findings of a template, for a topic."
  def profile_findings(template_id, topic), do: get_in(@profiles, [template_id, topic]) || []

  defp atomize(map) do
    Map.new(map, fn
      {"experiences", list} -> {:experiences, Enum.map(list, &atomize/1)}
      {key, value} -> {String.to_atom(key), value}
    end)
  end
end
