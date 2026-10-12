defmodule Portfolio.RecruitingDemo.Validations.NoCompensationFigures do
  @moduledoc """
  The Matcher sees the salary range, the Writer must not. Key points handed
  to the Writer are rejected if they mention pay or carry a salary-like
  figure ("60k", "60 k€"). Other amounts, such as revenue signed, are fine.
  """
  use Ash.Resource.Validation

  @pattern ~r/salar|salaire|compensation|rémunération|remuneration|\bpay\b|\b\d+\s*k(?:\s*(?:€|\$|eur|euros))?(?!\w)/iu

  def pattern, do: @pattern

  @impl true
  def validate(changeset, opts, _context) do
    field = opts[:attribute]
    values = changeset |> Ash.Changeset.get_attribute(field) |> List.wrap()

    if Enum.any?(values, &Regex.match?(@pattern, &1)),
      do: {:error, field: field, message: "must not mention compensation"},
      else: :ok
  end
end
