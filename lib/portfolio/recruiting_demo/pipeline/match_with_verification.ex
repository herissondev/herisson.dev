defmodule Portfolio.RecruitingDemo.Pipeline.MatchWithVerification do
  @moduledoc """
  Runs the Matcher; each time it asks a question, runs the research
  sub-Reactor and runs the Matcher again. The bound is the Ash validation on
  `ResearchRequest` (two requests): once it refuses, the Matcher has to
  conclude. `@max_turns` only guards against a model that never does.
  """
  use Reactor.Step

  alias Portfolio.RecruitingDemo.Pipeline
  alias Portfolio.RecruitingDemo.Pipeline.{MatcherReactor, VerificationReactor}
  alias Portfolio.RecruitingDemo.Resources.ResearchRequest

  @max_turns ResearchRequest.max_verifications() + 2

  @impl true
  def run(%{application_id: _}, context, _options), do: turn(context, 1, nil)

  defp turn(_context, turn, _feedback) when turn > @max_turns,
    do: {:error, "the Matcher did not conclude after #{@max_turns} turns"}

  # `feedback` tells the Matcher why its previous call was refused
  defp turn(context, turn, feedback) do
    with {:ok, result} <- Pipeline.run_sub(MatcherReactor, context, %{feedback: feedback}) do
      case outcome(result.tool_calls) do
        {:assessed, assessment} ->
          {:ok, assessment}

        {:verify, request_id, question} ->
          with {:ok, _} <- Pipeline.transition(context, :request_research),
               {:ok, _} <-
                 Pipeline.run_sub(VerificationReactor, context, %{
                   research_request_id: request_id,
                   question: question
                 }),
               {:ok, _} <- Pipeline.transition(context, :start_matching) do
            turn(context, turn + 1, nil)
          end

        # Refused request (limit reached) or nothing useful: ask again
        {:retry, reason} ->
          turn(context, turn + 1, reason)
      end
    end
  end

  defp outcome(tool_calls) do
    Enum.find_value(tool_calls, {:retry, refusal(tool_calls)}, fn
      %{tool: "submit_assessment", status: :ok, result: result} ->
        {:assessed, result}

      %{tool: "request_verification", status: :ok, result: %{id: id}, args: args} ->
        {:verify, id, args[:question] || args["question"]}

      _ ->
        nil
    end)
  end

  defp refusal(tool_calls) do
    Enum.find_value(tool_calls, "no tool call", fn
      %{status: status, tool: tool, reason: reason} when status != :ok -> "#{tool}: #{reason}"
      _ -> nil
    end)
  end
end
