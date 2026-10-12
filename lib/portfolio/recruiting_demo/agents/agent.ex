defmodule Portfolio.RecruitingDemo.Agents.Agent do
  @moduledoc """
  An agent builds its own input by reading data *as itself*: policies decide
  what it can see, and forbidden fields are dropped before the model gets
  anything. No conversation is shared between agents.
  """

  alias Portfolio.RecruitingDemo.Actor

  @doc "The agent's role (its actor role)."
  @callback role() :: atom()

  @doc "The exact input sent to the model, built from data readable by `actor`."
  @callback input(application_id :: Ecto.UUID.t(), actor :: Actor.t(), args :: map()) :: map()

  @doc "Keeps the readable fields of a record, as a plain map."
  def visible(nil, _fields), do: nil

  def visible(record, fields) do
    Enum.reduce(fields, %{}, fn field, acc ->
      case Map.get(record, field) do
        %Ash.ForbiddenField{} -> acc
        value -> Map.put(acc, field, plain(value))
      end
    end)
  end

  defp plain(list) when is_list(list), do: Enum.map(list, &plain/1)

  defp plain(%{__struct__: _} = struct) do
    if Ash.Resource.Info.resource?(struct.__struct__) do
      struct.__struct__
      |> Ash.Resource.Info.public_attributes()
      |> Enum.map(& &1.name)
      |> then(&visible(struct, &1))
    else
      struct
    end
  end

  defp plain(value), do: value
end
