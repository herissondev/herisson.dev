defmodule Portfolio.RecruitingDemo.PipelineFailureTest do
  # Not async: swaps the agent backend in the application env
  use ExUnit.Case

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.Agents.Simulated
  alias Portfolio.RecruitingDemo.Resources.ResearchRequest

  defmodule DownBackend do
    @moduledoc "A model provider that is always down."
    def call(_role, _input, _context), do: {:error, :service_unavailable}
  end

  defmodule SlowBackend do
    @moduledoc "A model that never answers in time."
    def call(_role, _input, _context), do: Process.sleep(:infinity)
  end

  defmodule StubbornBackend do
    @moduledoc "A Matcher that keeps asking for verifications, whatever it is told."
    def call(:matcher, _input, _context) do
      %{
        output: %{status: "needs_verification"},
        tool_calls: [%{tool: "request_verification", args: %{question: "Is Fintra real?"}}],
        model: "stubborn",
        usage: %{}
      }
    end

    def call(role, input, context), do: Simulated.call(role, input, context)
  end

  setup do
    config = Application.get_env(:portfolio, RecruitingDemo)
    on_exit(fn -> Application.put_env(:portfolio, RecruitingDemo, config) end)
    %{config: config}
  end

  defp with_config(config, overrides),
    do: Application.put_env(:portfolio, RecruitingDemo, Keyword.merge(config, overrides))

  defp run(template_id) do
    sid = RecruitingDemo.new_session_id()

    {:ok, application} =
      RecruitingDemo.submit(
        sid,
        RecruitingDemo.default_offer(),
        RecruitingDemo.cv_template(template_id),
        async?: false
      )

    {:ok, snapshot} = RecruitingDemo.snapshot(sid, application.id)
    snapshot
  end

  test "a model that keeps failing: retried, then compensated to failed", %{config: config} do
    with_config(config, agent_backend: DownBackend, agent_attempts: 3)

    s = run("aligned")

    assert s.application.state == :failed
    assert s.application.failure_reason =~ "triage failed after 3 attempt(s)"

    types = Enum.map(s.events, & &1.type)
    assert "step_failed" in types
    assert "compensated" in types

    assert Enum.find_index(types, &(&1 == "step_failed")) <
             Enum.find_index(types, &(&1 == "compensated"))

    assert Enum.any?(s.events, &(&1.payload == %{"from" => "triaging", "to" => "failed"}))
    assert RecruitingDemo.verify_journal(s.events) == :ok
  end

  test "a model that hangs is cut by the step timeout", %{config: config} do
    with_config(config, agent_backend: SlowBackend, agent_timeout_ms: 50, agent_attempts: 2)

    s = run("aligned")

    assert s.application.state == :failed
    assert s.application.failure_reason =~ ":timeout"
  end

  test "the verification loop is bounded by the Ash validation, not the model", %{config: config} do
    with_config(config, agent_backend: StubbornBackend)

    s = run("aligned")

    requests =
      Ash.read!(ResearchRequest, authorize?: false)
      |> Enum.filter(&(&1.application_id == s.application.id))

    assert length(requests) == ResearchRequest.max_verifications()
    # The model never concluded, so the run fails instead of looping forever
    assert s.application.state == :failed
    assert s.application.failure_reason =~ "did not conclude"
  end
end
