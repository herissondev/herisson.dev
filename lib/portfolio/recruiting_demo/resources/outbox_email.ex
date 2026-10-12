defmodule Portfolio.RecruitingDemo.Resources.OutboxEmail do
  @moduledoc "The fake outbox: the only destination of an email. Humans only."
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.{Audit, SetSession}
  alias Portfolio.RecruitingDemo.Checks.{ActorRole, Human}
  alias Portfolio.RecruitingDemo.Resources.Application
  alias Portfolio.RecruitingDemo.Validations.SameSession

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :to, :string, allow_nil?: false, public?: true
    attribute :subject, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, constraints: [trim?: false], public?: true
    attribute :sent_by, :string, public?: true
    create_timestamp :sent_at
  end

  actions do
    defaults [:read]

    create :deliver do
      accept [:application_id, :to, :subject, :body]
      change SetSession
      validate {SameSession, attribute: :application_id, resource: Application}

      change fn changeset, %{actor: actor} ->
        Ash.Changeset.force_change_attribute(changeset, :sent_by, "#{actor.kind}:#{actor.role}")
      end

      change {Audit, type: :email_sent, fields: [:id, :to]}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator]}
    end

    policy action(:deliver) do
      authorize_if Human
    end
  end
end
