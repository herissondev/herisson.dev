defmodule Portfolio.RecruitingDemo.Resources.AuditEvent do
  @moduledoc """
  One immutable journal entry, chained by hash to the previous one.
  There is no update nor destroy action: only `AuditLog` appends.
  """
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Checks.ActorRole

  @types ~w(state_transition agent_input agent_output tool_called tool_denied agent_message
            human_decision draft_edited email_sent step_failed compensated)

  def types, do: @types

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :seq, :integer, allow_nil?: false, public?: true
    attribute :at, :utc_datetime_usec, allow_nil?: false, public?: true
    attribute :actor_kind, :string, allow_nil?: false, public?: true
    attribute :actor_role, :string, allow_nil?: false, public?: true

    attribute :type, :string,
      allow_nil?: false,
      constraints: [match: "^(#{Enum.join(@types, "|")})$"],
      public?: true

    attribute :payload, :map, default: %{}, public?: true
    attribute :prev_hash, :string, allow_nil?: false, public?: true
    attribute :hash, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read]

    create :append do
      accept [
        :session_id,
        :application_id,
        :seq,
        :at,
        :actor_kind,
        :actor_role,
        :type,
        :payload,
        :prev_hash,
        :hash
      ]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator]}
    end

    # Only reachable through AuditLog, which flags its own calls
    policy action(:append) do
      authorize_if context_equals(:audit_log?, true)
    end
  end
end
