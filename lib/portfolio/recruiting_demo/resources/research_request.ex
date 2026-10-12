defmodule Portfolio.RecruitingDemo.Resources.ResearchRequest do
  @moduledoc "A question the Matcher sends to the Researcher (two at most)."
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.{Audit, SetSession}
  alias Portfolio.RecruitingDemo.Checks.ActorRole
  alias Portfolio.RecruitingDemo.Resources.Application
  alias Portfolio.RecruitingDemo.Validations.{ApplicationInState, MaxVerifications, SameSession}

  @max_verifications 2

  def max_verifications, do: @max_verifications

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :question, :string, allow_nil?: false, public?: true
    attribute :requested_by, :atom, default: :matcher, public?: true

    attribute :status, :atom,
      constraints: [one_of: [:pending, :answered]],
      default: :pending,
      public?: true

    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :request_verification do
      accept [:application_id, :question]
      change SetSession
      validate {SameSession, attribute: :application_id, resource: Application}
      validate {ApplicationInState, states: [:matching]}
      validate {MaxVerifications, max: @max_verifications}
      change {Audit, type: :agent_message, fields: [:question]}
    end

    update :answer do
      change set_attribute(:status, :answered)
    end
  end

  policies do
    policy action_type([:read, :update]) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :matcher, :researcher]}
    end

    policy action(:request_verification) do
      authorize_if {ActorRole, roles: [:matcher]}
    end

    policy action(:answer) do
      authorize_if {ActorRole, roles: [:researcher]}
    end
  end
end
