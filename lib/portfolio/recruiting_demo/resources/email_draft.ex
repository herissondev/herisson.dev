defmodule Portfolio.RecruitingDemo.Resources.EmailDraft do
  @moduledoc "Versions of the email: version 1 by the Writer, later ones by the visitor."
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.{Audit, NextDraftVersion, SetSession}
  alias Portfolio.RecruitingDemo.Checks.{ActorRole, Human}
  alias Portfolio.RecruitingDemo.Resources.Application
  alias Portfolio.RecruitingDemo.Validations.{ApplicationInState, SameSession}

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :version, :integer, allow_nil?: false, public?: true
    attribute :author_kind, :atom, constraints: [one_of: [:agent, :human]], public?: true
    attribute :subject, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, constraints: [trim?: false], public?: true
    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :create_draft do
      accept [:application_id, :subject, :body]
      change SetSession
      validate {SameSession, attribute: :application_id, resource: Application}
      validate {ApplicationInState, states: [:drafting]}
      change set_attribute(:version, 1)
      change set_attribute(:author_kind, :agent)
      change {Audit, type: :tool_called, fields: [:version]}
    end

    create :edit_draft do
      accept [:application_id, :subject, :body]
      change SetSession
      validate {SameSession, attribute: :application_id, resource: Application}
      validate {ApplicationInState, states: [:draft_ready]}
      change set_attribute(:author_kind, :human)
      change NextDraftVersion
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :writer]}
    end

    policy action(:create_draft) do
      authorize_if {ActorRole, roles: [:writer]}
    end

    policy action(:edit_draft) do
      authorize_if Human
    end
  end
end
