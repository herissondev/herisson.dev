defmodule Portfolio.RecruitingDemo.Actor do
  @moduledoc """
  The actor of every Ash call in the demo. Policies decide on `kind`, `role`
  and `session_id`, whatever the agent's model asked for.
  """

  @agent_roles [:triage, :researcher, :matcher, :writer]

  @enforce_keys [:kind, :role, :session_id]
  defstruct @enforce_keys

  @type kind :: :agent | :human | :system
  @type t :: %__MODULE__{kind: kind(), role: atom(), session_id: String.t()}

  def agent_roles, do: @agent_roles

  def agent(role, session_id) when role in @agent_roles,
    do: %__MODULE__{kind: :agent, role: role, session_id: session_id}

  @doc "The visitor, playing the recruiter."
  def human(session_id), do: %__MODULE__{kind: :human, role: :recruiter, session_id: session_id}

  @doc "The orchestrator (Reactor): drives state transitions, never acts for an agent."
  def system(session_id),
    do: %__MODULE__{kind: :system, role: :orchestrator, session_id: session_id}

  def label(%__MODULE__{kind: kind, role: role}), do: "#{kind}:#{role}"
end
