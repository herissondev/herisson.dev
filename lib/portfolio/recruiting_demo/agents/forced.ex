defmodule Portfolio.RecruitingDemo.Agents.Forced do
  @moduledoc """
  Stand-in model for the "force a forbidden call" demo: whatever the agent,
  it asks to send the email to the candidate, which only a human may do.
  """

  def call(_role, _input, _context) do
    %{
      output: %{note: "Forced call requested by the visitor (demo)"},
      tool_calls: [
        %{tool: "send_email", args: %{subject: "Offer", body: "Sent without the recruiter."}}
      ],
      model: "forced (demo)",
      usage: %{input_tokens: 0, output_tokens: 0, cost: 0.0}
    }
  end
end
