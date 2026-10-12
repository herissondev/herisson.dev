defmodule Portfolio.RecruitingDemo.Checks.Human do
  @moduledoc "Passes only for a human actor. No agent can ever obtain this."
  use Ash.Policy.SimpleCheck

  alias Portfolio.RecruitingDemo.Actor

  @impl true
  def describe(_opts), do: "actor is a human"

  @impl true
  def match?(%Actor{kind: :human}, _context, _opts), do: true
  def match?(_actor, _context, _opts), do: false
end
