defmodule Portfolio.RecruitingDemo.Resources.CvSubmission do
  @moduledoc """
  The CV picked from the demo templates, then edited by the visitor.

  `age`, `family_status` and `origin` are protected criteria: only the human
  and the orchestrator can read them, never the Matcher.
  """
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer]

  alias Portfolio.RecruitingDemo.Changes.SetSession
  alias Portfolio.RecruitingDemo.Checks.{ActorRole, Human}
  alias Portfolio.RecruitingDemo.Resources.Experience

  @editable [
    :template_id,
    :name,
    :email,
    :headline,
    :years_experience,
    :experiences,
    :skills,
    :raw_text,
    :age,
    :family_status,
    :origin
  ]

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true
    attribute :template_id, :string, public?: true
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :email, :string, public?: true
    attribute :headline, :string, public?: true
    attribute :years_experience, :integer, public?: true
    attribute :experiences, {:array, Experience}, default: [], public?: true
    attribute :skills, {:array, :string}, default: [], public?: true

    attribute :raw_text, :string,
      default: "",
      constraints: [max_length: 20_000, trim?: false],
      public?: true

    attribute :age, :integer, public?: true
    attribute :family_status, :string, public?: true
    attribute :origin, :string, public?: true
    create_timestamp :inserted_at
  end

  actions do
    defaults [:read]

    create :submit do
      accept @editable
      change SetSession
    end

    update :edit do
      accept @editable
    end
  end

  policies do
    policy action_type([:read, :update]) do
      authorize_if expr(session_id == ^actor(:session_id))
    end

    policy action_type(:read) do
      authorize_if {ActorRole,
                    roles: [:recruiter, :orchestrator, :triage, :researcher, :matcher, :writer]}
    end

    policy action([:submit, :edit]) do
      authorize_if Human
    end
  end

  field_policies do
    field_policy [:session_id, :template_id] do
      authorize_if always()
    end

    field_policy :name do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :researcher, :matcher, :writer]}
    end

    field_policy :raw_text do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :triage]}
    end

    field_policy :experiences do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :researcher, :matcher]}
    end

    field_policy [:headline, :years_experience, :skills] do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator, :matcher]}
    end

    field_policy [:email, :age, :family_status, :origin] do
      authorize_if {ActorRole, roles: [:recruiter, :orchestrator]}
    end
  end
end
