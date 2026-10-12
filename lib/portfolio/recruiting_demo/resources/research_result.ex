defmodule Portfolio.RecruitingDemo.Resources.ResearchResult do
  @moduledoc """
  What the Researcher found on a topic, read from the pre-written fixtures
  (the research is simulated).
  """
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.{Audit, SetSession}
  alias Portfolio.RecruitingDemo.Checks.ActorRole
  alias Portfolio.RecruitingDemo.Resources.{Application, Finding}
  alias Portfolio.RecruitingDemo.Validations.SameSession

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :application_id, :uuid, allow_nil?: false, public?: true
    attribute :research_request_id, :uuid, public?: true
    attribute :topic, :string, allow_nil?: false, public?: true
    attribute :findings, {:array, Finding}, default: [], public?: true
    attribute :fixture_source, :string, public?: true
    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :record do
      accept [:application_id, :research_request_id, :topic, :findings, :fixture_source]
      change SetSession
      validate {SameSession, attribute: :application_id, resource: Application}
      change {Audit, type: :tool_called, fields: [:topic, :fixture_source]}
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :researcher, :matcher]}
    end

    policy action(:record) do
      authorize_if {ActorRole, roles: [:researcher]}
    end
  end
end
