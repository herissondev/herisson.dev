defmodule Portfolio.RecruitingDemo.Resources.Assessment do
  @moduledoc """
  The Matcher's report. The Writer only reads `recommendation` and
  `key_points`, and key points can not carry compensation figures.
  """
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.{Audit, SetSession}
  alias Portfolio.RecruitingDemo.Checks.ActorRole
  alias Portfolio.RecruitingDemo.Resources.Application

  alias Portfolio.RecruitingDemo.Validations.{
    ApplicationInState,
    NoCompensationFigures,
    SameSession
  }

  @report [:strengths, :weaknesses, :gaps, :cv_citations, :verification_notes]

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :strengths, {:array, :string}, default: [], public?: true
    attribute :weaknesses, {:array, :string}, default: [], public?: true
    attribute :gaps, {:array, :string}, default: [], public?: true
    attribute :cv_citations, {:array, :string}, default: [], public?: true
    attribute :verification_notes, {:array, :string}, default: [], public?: true

    attribute :recommendation, :atom,
      allow_nil?: false,
      constraints: [one_of: [:strong_yes, :yes, :maybe, :no]],
      public?: true

    attribute :key_points, {:array, :string}, default: [], public?: true
    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :submit_assessment do
      accept [:application_id, :recommendation, :key_points | @report]
      change SetSession
      validate {SameSession, attribute: :application_id, resource: Application}
      validate {ApplicationInState, states: [:matching]}
      validate {NoCompensationFigures, attribute: :key_points}
      change {Audit, type: :tool_called, fields: [:recommendation]}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :matcher, :writer]}
    end

    policy action(:submit_assessment) do
      authorize_if {ActorRole, roles: [:matcher]}
    end
  end

  field_policies do
    field_policy [:session_id, :application_id, :recommendation, :key_points] do
      authorize_if always()
    end

    field_policy @report do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :matcher]}
    end
  end
end
