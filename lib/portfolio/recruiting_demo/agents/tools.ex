defmodule Portfolio.RecruitingDemo.Agents.Tools do
  @moduledoc """
  Every tool an agent may call, each one a single Ash action run as the
  agent's actor. An agent is only *offered* the tools of its role, but any
  call, even a forced one, goes through the same policies: a refusal comes
  back as `:denied` and is journaled as `tool_denied`.
  """

  alias Portfolio.RecruitingDemo.Actor

  alias Portfolio.RecruitingDemo.Resources.{
    Application,
    Assessment,
    EmailDraft,
    ResearchRequest,
    ResearchResult
  }

  @by_role %{
    triage: ~w(classify),
    researcher: ~w(search_profile answer_verification),
    matcher: ~w(request_verification submit_assessment),
    writer: ~w(create_draft)
  }

  # The Ash action behind each tool, authorized before anything else runs.
  # Updates are authorized against the record they would change.
  @actions %{
    "classify" => {:update, Application, :record_triage},
    "search_profile" => {:create, ResearchResult, :search_profile},
    "answer_verification" => {:update, ResearchRequest, :answer},
    "request_verification" => {:create, ResearchRequest, :request_verification},
    "submit_assessment" => {:create, Assessment, :submit_assessment},
    "create_draft" => {:create, EmailDraft, :create_draft},
    "send_email" => {:update, Application, :send_email}
  }

  @doc "Tool names offered to a role."
  def for_role(role), do: Map.fetch!(@by_role, role)

  @doc "Every tool name an agent could try to call, including the human-only ones."
  def all, do: (@by_role |> Map.values() |> List.flatten()) ++ ~w(send_email)

  @type call :: %{tool: String.t(), args: map()}
  @type result :: %{
          tool: String.t(),
          args: map(),
          status: :ok | :denied | :invalid | :unknown,
          result: term(),
          reason: String.t() | nil
        }

  @doc "Runs one tool call as `actor`, within `application_id`."
  @spec execute(call(), Actor.t(), Ecto.UUID.t()) :: result()
  def execute(%{tool: tool, args: args} = call, %Actor{} = actor, application_id) do
    args = stringify(args)

    with :ok <- authorize(tool, args, actor, application_id) do
      run(tool, args, actor, application_id)
    end
    |> to_result(call)
  end

  # Policies first: a forbidden call is reported as such, not as whatever
  # validation (e.g. the state machine) would have failed afterwards.
  defp authorize(tool, args, actor, application_id) do
    with {:ok, subject} <- subject(Map.get(@actions, tool), args, actor, application_id) do
      case Ash.can(subject, actor, return_forbidden_error?: true, maybe_is: true) do
        {:ok, true} -> :ok
        {:ok, true, _} -> :ok
        {:ok, false, error} -> {:error, error}
        {:ok, false} -> {:error, Ash.Error.Forbidden.exception([])}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp subject(nil, _args, _actor, _application_id), do: {:error, :unknown_tool}

  defp subject({:create, resource, action}, _args, _actor, _application_id),
    do: {:ok, {resource, action}}

  defp subject({:update, resource, action}, args, actor, application_id) do
    id = if resource == Application, do: application_id, else: args["research_request_id"]

    with {:ok, record} <- Ash.get(resource, id, actor: actor), do: {:ok, {record, action}}
  end

  defp run("classify", args, actor, application_id) do
    with {:ok, application} <- Ash.get(Application, application_id, actor: actor) do
      application
      |> Ash.Changeset.for_update(
        :record_triage,
        %{
          triage_category: args["category"],
          triage_confidence: args["confidence"],
          triage_source: args["source"] || :simulated
        },
        actor: actor
      )
      |> Ash.update()
    end
  end

  defp run("search_profile", args, actor, application_id) do
    ResearchResult
    |> Ash.Changeset.for_create(
      :search_profile,
      %{
        application_id: application_id,
        topic: args["topic"],
        query: args["query"],
        research_request_id: args["research_request_id"]
      },
      actor: actor
    )
    |> Ash.create()
  end

  defp run("answer_verification", args, actor, _application_id) do
    with {:ok, request} <- Ash.get(ResearchRequest, args["research_request_id"], actor: actor) do
      request |> Ash.Changeset.for_update(:answer, %{}, actor: actor) |> Ash.update()
    end
  end

  defp run("request_verification", args, actor, application_id) do
    ResearchRequest
    |> Ash.Changeset.for_create(
      :request_verification,
      %{application_id: application_id, question: args["question"]},
      actor: actor
    )
    |> Ash.create()
  end

  defp run("submit_assessment", args, actor, application_id) do
    Assessment
    |> Ash.Changeset.for_create(
      :submit_assessment,
      Map.put(args, "application_id", application_id),
      actor: actor
    )
    |> Ash.create()
  end

  defp run("create_draft", args, actor, application_id) do
    EmailDraft
    |> Ash.Changeset.for_create(
      :create_draft,
      %{application_id: application_id, subject: args["subject"], body: args["body"]},
      actor: actor
    )
    |> Ash.create()
  end

  # Human-only: no agent is offered it, but a forced call must hit the policy
  defp run("send_email", args, actor, application_id) do
    with {:ok, application} <- Ash.get(Application, application_id, actor: actor) do
      application
      |> Ash.Changeset.for_update(
        :send_email,
        %{subject: args["subject"], body: args["body"]},
        actor: actor
      )
      |> Ash.update()
    end
  end

  defp run(_unknown, _args, _actor, _application_id), do: {:error, :unknown_tool}

  defp to_result({:ok, record}, call),
    do: Map.merge(call, %{status: :ok, result: summary(record), reason: nil})

  defp to_result({:error, :unknown_tool}, call),
    do: Map.merge(call, %{status: :unknown, result: nil, reason: "unknown tool"})

  defp to_result({:error, error}, call) do
    case Ash.Error.to_error_class(error) do
      %Ash.Error.Forbidden{} = forbidden ->
        reason = if match?(%Ash.Error.Forbidden.Policy{}, error), do: error, else: forbidden
        Map.merge(call, %{status: :denied, result: nil, reason: policy_reason(reason)})

      other ->
        Map.merge(call, %{status: :invalid, result: nil, reason: Exception.message(other)})
    end
  end

  # The policy breakdown, without stacktraces: which checks failed and why
  defp policy_reason(%Ash.Error.Forbidden{errors: errors} = error) do
    case Enum.find(errors, &match?(%Ash.Error.Forbidden.Policy{}, &1)) do
      nil ->
        error
        |> Ash.Error.to_error_class()
        |> Map.get(:errors)
        |> Enum.map_join("; ", &Exception.message/1)

      policy ->
        policy_reason(policy)
    end
  end

  defp policy_reason(%Ash.Error.Forbidden.Policy{} = policy),
    do: policy |> Ash.Error.Forbidden.Policy.report(help_text?: false) |> String.trim()

  defp summary(%{__struct__: resource, id: id}), do: %{resource: inspect(resource), id: id}

  defp stringify(args), do: Map.new(args, fn {k, v} -> {to_string(k), v} end)
end
