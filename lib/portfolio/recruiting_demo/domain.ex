defmodule Portfolio.RecruitingDemo.Domain do
  @moduledoc "Ash domain of the recruiting demo. Every resource lives in ETS."
  use Ash.Domain, otp_app: :portfolio, extensions: [AshAi]

  alias Portfolio.RecruitingDemo.Resources

  # Actions offered to the LLM agents as tools. Which ones an agent gets is
  # decided by its role; whether a call may run is decided by the policies.
  tools do
    tool :search_profile, Resources.ResearchResult, :search_profile do
      description "Search the simulated public sources about the candidate on one topic."
    end

    tool :answer_verification, Resources.ResearchRequest, :answer do
      description "Mark a verification request from the Matcher as answered."
    end

    tool :request_verification, Resources.ResearchRequest, :request_verification do
      description "Ask the Researcher to verify one doubtful claim of the CV."
    end

    tool :submit_assessment, Resources.Assessment, :submit_assessment do
      description "Submit the final assessment of the candidate for the recruiter."
    end

    tool :create_draft, Resources.EmailDraft, :create_draft do
      description "Create the email draft for the recruiter to review."
    end
  end

  resources do
    resource Resources.JobOffer
    resource Resources.CvSubmission
    resource Resources.Application
    resource Resources.ResearchRequest
    resource Resources.ResearchResult
    resource Resources.Assessment
    resource Resources.EmailDraft
    resource Resources.OutboxEmail
    resource Resources.AuditEvent
  end
end
