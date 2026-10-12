defmodule Portfolio.RecruitingDemo.Agents.Live do
  @moduledoc """
  Real models: Jev for the triage (with an LLM fallback when it is down),
  an OpenRouter LLM for the other agents.

  Each LLM agent is offered the tools Ash AI derives from the Ash actions,
  filtered by its actor: it only sees the tools of its role. The calls it
  asks for are then run (and authorized again) by `Agents.Tools`.
  Above the daily cost cap, it falls back to the simulated models.
  """

  alias Portfolio.RecruitingDemo
  alias Portfolio.RecruitingDemo.{Actor, Budget}
  alias Portfolio.RecruitingDemo.Agents.{Jev, Prompts, Simulated, Tools, Triage}

  # Jev input price, USD per token
  @jev_input_price 0.042 / 1_000_000

  def available?, do: openrouter_key() not in [nil, ""]

  def call(role, input, context) do
    cond do
      Budget.daily_cap_reached?() ->
        role
        |> Simulated.call(input, context)
        |> Map.update!(:output, &Map.put(&1, :note, "daily cost cap reached: simulated model"))

      true ->
        with :ok <- Budget.check_application(context.application_id) do
          do_call(role, input, context)
        end
    end
  end

  defp do_call(:triage, input, _context) do
    with true <- Jev.available?(),
         {:ok, answer} <- Jev.classify(input) do
      usage = %{
        input_tokens: answer.usage["input_tokens"] || 0,
        output_tokens: answer.usage["output_tokens"] || 0,
        cost: (answer.usage["input_tokens"] || 0) * @jev_input_price
      }

      Budget.spend(usage.cost)
      triage(answer.category, answer.confidence, "jev", answer.model, usage)
    else
      false -> llm_triage(input, :jev_not_configured)
      {:error, reason} -> llm_triage(input, reason)
    end
  end

  defp do_call(role, input, context) do
    actor = Actor.agent(role, context.session_id)

    tools =
      AshAi.list_tools(
        otp_app: :portfolio,
        actor: actor,
        tools: Enum.map(Tools.for_role(role), &String.to_existing_atom/1),
        strict: false
      )

    messages = [
      ReqLLM.Context.system(Prompts.system(role)),
      ReqLLM.Context.user(Prompts.user(input))
    ]

    case ReqLLM.generate_text(model(), messages,
           tools: tools,
           tool_choice: "required",
           receive_timeout: timeout()
         ) do
      {:ok, response} ->
        usage = usage(response)
        Budget.spend(usage.cost)

        calls = Enum.map(ReqLLM.Response.tool_calls(response), &to_call/1)

        %{
          output: %{text: ReqLLM.Response.text(response), tool_calls: Enum.map(calls, & &1.tool)},
          tool_calls: calls,
          model: response.model || model(),
          usage: usage
        }

      {:error, error} ->
        {:error, {:llm, Exception.message(error)}}
    end
  end

  # Jev unavailable: the same closed decision, asked to the LLM
  defp llm_triage(input, reason) do
    schema = [
      category: [type: {:in, Triage.categories()}, required: true],
      confidence: [type: :float, required: true]
    ]

    messages = [
      ReqLLM.Context.system(Prompts.system(:triage)),
      ReqLLM.Context.user(Prompts.user(input))
    ]

    case ReqLLM.generate_object(model(), messages, schema, receive_timeout: timeout()) do
      {:ok, response} ->
        object = ReqLLM.Response.object(response)
        usage = usage(response)
        Budget.spend(usage.cost)

        triage(object["category"], object["confidence"], "llm_fallback", model(), usage)
        |> Map.update!(:output, &Map.put(&1, :fallback_reason, inspect(reason)))

      {:error, error} ->
        {:error, {:triage, inspect(reason), Exception.message(error)}}
    end
  end

  defp triage(category, confidence, source, model, usage) do
    output = %{category: category, confidence: confidence, source: source}

    %{
      output: output,
      tool_calls: [%{tool: "classify", args: output}],
      model: model,
      usage: usage
    }
  end

  defp to_call(tool_call) do
    name = ReqLLM.ToolCall.name(tool_call)
    args = tool_call |> ReqLLM.ToolCall.args_json() |> decode()
    args = Map.get(args, "input", args)

    args =
      if name == "answer_verification",
        do: Map.put_new(args, "research_request_id", args["id"]),
        else: args

    %{tool: name, args: args}
  end

  defp decode(nil), do: %{}
  defp decode(map) when is_map(map), do: map

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp usage(%{usage: usage}) when is_map(usage) do
    %{
      input_tokens: usage[:input_tokens] || 0,
      output_tokens: usage[:output_tokens] || 0,
      cost: usage[:total_cost] || usage["cost"] || 0.0
    }
  end

  defp usage(_response), do: %{input_tokens: 0, output_tokens: 0, cost: 0.0}

  defp config, do: Keyword.get(RecruitingDemo.config(), :llm, [])
  defp model, do: Keyword.get(config(), :model, "openrouter:~deepseek/deepseek-flash-latest")
  defp timeout, do: Keyword.get(RecruitingDemo.config(), :agent_timeout_ms, 30_000)

  defp openrouter_key,
    do: Application.get_env(:req_llm, :openrouter_api_key) || System.get_env("OPENROUTER_API_KEY")
end
