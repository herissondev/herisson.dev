defmodule Portfolio.RecruitingDemo.Checks.ActorRole do
  @moduledoc "Passes when the actor's role is one of `roles`."
  use Ash.Policy.SimpleCheck

  alias Portfolio.RecruitingDemo.Actor

  @impl true
  def describe(opts), do: "actor role is one of #{inspect(opts[:roles])}"

  @impl true
  def match?(%Actor{role: role}, _context, opts), do: role in opts[:roles]
  def match?(_actor, _context, _opts), do: false
end
