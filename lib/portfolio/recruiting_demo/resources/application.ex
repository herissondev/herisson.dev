defmodule Portfolio.RecruitingDemo.Resources.Application do
  @moduledoc """
  A candidature, carrier of the state machine. Any transition that is not
  declared below is refused by Ash, whoever attempts it.
  """
  use Ash.Resource,
    domain: Portfolio.RecruitingDemo.Domain,
    data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshStateMachine]

  alias Portfolio.RecruitingDemo.Changes.{
    Audit,
    AuditTransition,
    RouteTriage,
    SendEmail,
    SetSession
  }

  alias Portfolio.RecruitingDemo.Checks.{ActorRole, Human}
  alias Portfolio.RecruitingDemo.Resources.{CvSubmission, JobOffer}
  alias Portfolio.RecruitingDemo.Validations.SameSession

  @automatic_states [:received, :triaging, :researching, :matching, :drafting]

  def automatic_states, do: @automatic_states

  state_machine do
    initial_states [:received]
    default_initial_state :received

    transitions do
      transition :start_triage, from: :received, to: :triaging

      transition :route_after_triage,
        from: :triaging,
        to: [:researching, :rejected, :manual_review]

      transition :review, from: :manual_review, to: [:researching, :rejected]
      transition :start_matching, from: :researching, to: :matching
      transition :request_research, from: :matching, to: :researching
      transition :await_decision, from: :matching, to: :awaiting_decision
      transition :decide, from: :awaiting_decision, to: [:drafting, :rejected]
      transition :mark_draft_ready, from: :drafting, to: :draft_ready
      transition :send_email, from: :draft_ready, to: :sent
      transition :fail, from: @automatic_states, to: :failed
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :session_id, :string, allow_nil?: false, public?: true

    attribute :triage_category, :atom,
      constraints: [one_of: [:relevant, :off_position, :unrelated, :suspect]],
      public?: true

    attribute :triage_confidence, :float, public?: true

    attribute :triage_source, :atom,
      constraints: [one_of: [:jev, :llm_fallback, :simulated]],
      public?: true

    attribute :decision, :atom, constraints: [one_of: [:yes, :no]], public?: true
    attribute :failure_reason, :string, public?: true
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :job_offer, JobOffer, allow_nil?: false, public?: true, attribute_writable?: true

    belongs_to :cv_submission, CvSubmission,
      allow_nil?: false,
      public?: true,
      attribute_writable?: true
  end

  actions do
    defaults [:read]

    create :submit do
      accept [:job_offer_id, :cv_submission_id]
      change SetSession
      validate {SameSession, attribute: :job_offer_id, resource: JobOffer}
      validate {SameSession, attribute: :cv_submission_id, resource: CvSubmission}
      change AuditTransition
    end

    # Orchestrator transitions
    update :start_triage do
      require_atomic? false
      change transition_state(:triaging)
      change AuditTransition
    end

    update :route_after_triage do
      require_atomic? false
      change RouteTriage
      change AuditTransition
    end

    update :start_matching do
      require_atomic? false
      change transition_state(:matching)
      change AuditTransition
    end

    update :request_research do
      require_atomic? false
      change transition_state(:researching)
      change AuditTransition
    end

    update :await_decision do
      require_atomic? false
      change transition_state(:awaiting_decision)
      change AuditTransition
    end

    update :mark_draft_ready do
      require_atomic? false
      change transition_state(:draft_ready)
      change AuditTransition
    end

    update :fail do
      require_atomic? false
      accept [:failure_reason]
      change transition_state(:failed)
      change AuditTransition
    end

    # Triage agent: records its classification, does not move the state
    update :record_triage do
      require_atomic? false
      accept [:triage_category, :triage_confidence, :triage_source]
      validate attribute_equals(:state, :triaging)
    end

    # Human actions
    update :review do
      require_atomic? false
      argument :approve, :boolean, allow_nil?: false

      change fn changeset, _context ->
        target =
          if Ash.Changeset.get_argument(changeset, :approve), do: :researching, else: :rejected

        AshStateMachine.transition_state(changeset, target)
      end

      change {Audit, type: :human_decision, fields: [:approve]}
      change AuditTransition
    end

    update :decide do
      require_atomic? false
      argument :decision, :atom, allow_nil?: false, constraints: [one_of: [:yes, :no]]

      change fn changeset, _context ->
        decision = Ash.Changeset.get_argument(changeset, :decision)
        target = if decision == :yes, do: :drafting, else: :rejected

        changeset
        |> Ash.Changeset.force_change_attribute(:decision, decision)
        |> AshStateMachine.transition_state(target)
      end

      change {Audit, type: :human_decision, fields: [:decision]}
      change AuditTransition
    end

    update :send_email do
      require_atomic? false
      argument :subject, :string, allow_nil?: false
      argument :body, :string, allow_nil?: false, constraints: [trim?: false]
      change transition_state(:sent)
      change SendEmail
      change AuditTransition
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

    policy action([
             :start_triage,
             :route_after_triage,
             :start_matching,
             :request_research,
             :await_decision,
             :mark_draft_ready,
             :fail
           ]) do
      authorize_if {ActorRole, roles: [:orchestrator]}
    end

    policy action(:record_triage) do
      authorize_if {ActorRole, roles: [:triage]}
    end

    policy action([:submit, :review, :decide, :send_email]) do
      authorize_if Human
    end
  end
end
