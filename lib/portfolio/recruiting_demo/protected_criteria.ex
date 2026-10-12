defmodule Portfolio.RecruitingDemo.ProtectedCriteria do
  @moduledoc """
  Removes discriminatory criteria (age, family situation, origin) from the
  Matcher's input before it is built. A pure function: the guarantee does not
  depend on the model following an instruction.

  The structured fields are already hidden by field policies; this also
  redacts them from free text such as a headline or an experience summary.
  """

  @fields [:age, :family_status, :origin, :date_of_birth, :nationality, :gender, :photo]

  @patterns [
    ~r/\b\d{2}\s*(years old|ans|yo)\b/iu,
    ~r/\b(born|né|née)\s+(in|en|le)\s+[\w\s]+?\d{4}\b/iu,
    ~r/\b(single|married|divorced|widowed|célibataire|marié|mariée|divorcé|divorcée|veuf|veuve|pacsé|pacsée)\b(\s+with\s+\w+\s+child(ren)?|\s+avec\s+\w+\s+enfants?)?/iu,
    ~r/\b(\w+|\d+)\s+(children|child|kids|enfants?)\b/iu,
    ~r/\b[\w-]+\s+(nationality|origin)\b|\b(nationalité|origine)\s+[\w-]+/iu,
    ~r/\b(male|female|homme|femme)\b/iu
  ]

  @redacted "[redacted]"

  def fields, do: @fields

  @doc "Strips protected fields and redacts protected mentions, recursively."
  def strip(%{} = map) when not is_struct(map) do
    map
    |> Map.drop(@fields)
    |> Map.new(fn {key, value} -> {key, strip(value)} end)
  end

  def strip(list) when is_list(list), do: Enum.map(list, &strip/1)

  def strip(text) when is_binary(text),
    do: Enum.reduce(@patterns, text, &Regex.replace(&1, &2, @redacted))

  def strip(other), do: other
end
