defmodule Portfolio.RecruitingDemo.Resources.JobOffer do
  @moduledoc "The position configured by the visitor."
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.SetSession
  alias Portfolio.RecruitingDemo.Checks.{ActorRole, Human}

  @details [
    :salary_min,
    :salary_max,
    :min_years,
    :required_skills,
    :nice_to_have_skills,
    :location,
    :remote
  ]

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :salary_min, :integer, public?: true
    attribute :salary_max, :integer, public?: true
    attribute :min_years, :integer, default: 0, public?: true
    attribute :required_skills, {:array, :string}, default: [], public?: true
    attribute :nice_to_have_skills, {:array, :string}, default: [], public?: true
    attribute :location, :string, public?: true

    attribute :remote, :atom,
      constraints: [one_of: [:none, :hybrid, :full]],
      default: :hybrid,
      public?: true

    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :configure do
      accept [:title | @details]
      change SetSession
    end

    update :edit do
      accept [:title | @details]
    end
  end

  policies do
    policy action_type([:read, :update]) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :triage, :matcher, :writer]}
    end

    policy action([:configure, :edit]) do
      authorize_if Human
    end
  end

  field_policies do
    field_policy [:session_id, :title] do
      authorize_if always()
    end

    # Triage and Writer only get the job title
    field_policy @details do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :matcher]}
    end
  end
end
