defmodule PortfolioWeb.RecruitingDemo.Forms do
  @moduledoc """
  Converts between the demo's attributes and flat form params: lists are
  comma separated, experiences are one per line as
  `Company | Role | 2020-2023 | Summary`.
  """

  @offer_fields ~w(title salary_min salary_max min_years required_skills nice_to_have_skills location remote)
  @cv_fields ~w(template_id name email headline years_experience skills experiences raw_text age family_status origin)

  def offer_params(offer) do
    Map.new(@offer_fields, fn field ->
      {field, to_param(Map.get(offer, String.to_existing_atom(field)))}
    end)
  end

  def cv_params(cv) do
    Map.new(@cv_fields, fn
      "experiences" -> {"experiences", experiences_to_text(cv[:experiences] || [])}
      field -> {field, to_param(Map.get(cv, String.to_existing_atom(field)))}
    end)
  end

  def offer_attrs(params) do
    %{
      title: params["title"],
      salary_min: integer(params["salary_min"]),
      salary_max: integer(params["salary_max"]),
      min_years: integer(params["min_years"]) || 0,
      required_skills: list(params["required_skills"]),
      nice_to_have_skills: list(params["nice_to_have_skills"]),
      location: blank_to_nil(params["location"]),
      remote: params["remote"]
    }
  end

  def cv_attrs(params) do
    %{
      template_id: params["template_id"],
      name: params["name"],
      email: blank_to_nil(params["email"]),
      headline: blank_to_nil(params["headline"]),
      years_experience: integer(params["years_experience"]),
      skills: list(params["skills"]),
      experiences: experiences_from_text(params["experiences"] || ""),
      raw_text: params["raw_text"] || "",
      age: integer(params["age"]),
      family_status: blank_to_nil(params["family_status"]),
      origin: blank_to_nil(params["origin"])
    }
  end

  def experiences_to_text(experiences) do
    Enum.map_join(experiences, "\n", fn exp ->
      years = Enum.join([exp[:start_year], exp[:end_year]] |> Enum.reject(&is_nil/1), "-")
      Enum.join([exp[:company], exp[:role], years, exp[:summary]], " | ")
    end)
  end

  def experiences_from_text(text) do
    text
    |> String.split("\n", trim: true)
    |> Enum.map(&(String.split(&1, "|") |> Enum.map(fn part -> String.trim(part) end)))
    |> Enum.flat_map(fn
      [company, role | rest] when company != "" and role != "" ->
        {start_year, end_year} = years(Enum.at(rest, 0))

        [
          %{
            company: company,
            role: role,
            start_year: start_year,
            end_year: end_year,
            summary: Enum.at(rest, 1)
          }
        ]

      _ ->
        []
    end)
  end

  defp years(nil), do: {nil, nil}

  defp years(text) do
    case String.split(text, "-", trim: true) do
      [from, to] -> {integer(from), integer(to)}
      [from] -> {integer(from), nil}
      _ -> {nil, nil}
    end
  end

  defp to_param(nil), do: ""
  defp to_param(list) when is_list(list), do: Enum.join(list, ", ")
  defp to_param(value), do: to_string(value)

  defp list(nil), do: []

  defp list(text),
    do: text |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp integer(nil), do: nil

  defp integer(text) do
    case Integer.parse(String.trim(to_string(text))) do
      {value, _} -> value
      :error -> nil
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(text), do: if(String.trim(text) == "", do: nil, else: text)
end
