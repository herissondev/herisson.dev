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
  def run(%{application_id: _}, context, _options), do: turn(context, 1)

  defp turn(_context, turn) when turn > @max_turns,
    do: {:error, "the Matcher did not conclude after #{@max_turns} turns"}

  defp turn(context, turn) do
    with {:ok, result} <- Pipeline.run_sub(MatcherReactor, context) do
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
            turn(context, turn + 1)
          end

        # Refused request (limit reached) or nothing useful: ask again
        :retry ->
          turn(context, turn + 1)
      end
    end
  end

  defp outcome(tool_calls) do
    Enum.find_value(tool_calls, :retry, fn
      %{tool: "submit_assessment", status: :ok, result: result} ->
        {:assessed, result}

      %{tool: "request_verification", status: :ok, result: %{id: id}, args: args} ->
        {:verify, id, args[:question] || args["question"]}

      _ ->
        nil
    end)
  end
end
