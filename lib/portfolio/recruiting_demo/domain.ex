defmodule Portfolio.RecruitingDemo.Domain do
  @moduledoc "Ash domain of the recruiting demo. Every resource lives in ETS."
  use Ash.Domain, otp_app: :portfolio

  alias Portfolio.RecruitingDemo.Resources

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
