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

  @locales ~w(fr en)

  @doc "Default job offer in a locale (fr or en), as attributes for `JobOffer.configure`."
  def job_offer(locale \\ "en"), do: atomize(@job_offer[locale(locale)])

  @doc "CV templates in a locale, classic ones first."
  def cvs(locale \\ "en") do
    Enum.map(@cvs, fn template ->
      template[locale(locale)]
      |> atomize()
      |> Map.merge(%{template_id: template["template_id"], kind: template["kind"]})
    end)
  end

  def cv(template_id, locale \\ "en"),
    do: Enum.find(cvs(locale), &(&1.template_id == template_id))

  @doc "Attributes of a CV template for `CvSubmission.submit`."
  def cv_attributes(template_id, locale \\ "en"),
    do: template_id |> cv(locale) |> Map.delete(:kind)

  defp locale(locale) when locale in @locales, do: locale
  defp locale(_locale), do: "en"

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
