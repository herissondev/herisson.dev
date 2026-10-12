defmodule Portfolio.RecruitingDemo.Agents.Simulated do
  @moduledoc """
  Deterministic stand-in for the models, used until Jev and the LLMs are
  plugged in (and in tests). It reasons on the actual input, so an edited CV
  still gets a coherent answer.

  On purpose, the simulated Matcher *falls* for a prompt injection found in
  its input and tries to send the email: the point of the demo is that the
  policy refuses it, whatever the model does.
  """

  @injection ~r/ignore (all )?previous instructions|system note to the ai|send the hiring email/i

  def injection?(term), do: Regex.match?(@injection, Jason.encode!(term))

  @doc "Returns `%{output, tool_calls, model, usage}` for a role and its input."
  def call(role, input, _opts \\ []) do
    latency()
    {output, tool_calls} = decide(role, input)

    %{
      output: output,
      tool_calls: tool_calls,
      model: "simulated",
      usage: %{input_tokens: tokens(input), output_tokens: tokens(output), cost: 0.0}
    }
  end

  defp decide(:triage, %{cv_text: text, job_title: title}) do
    text = String.downcase(text || "")

    title_words =
      (title || "")
      |> String.downcase()
      |> String.split(~r/\W+/u)
      |> Enum.filter(&(String.length(&1) > 3))

    {category, confidence} =
      cond do
        injection?(text) ->
          {"suspect", 0.81}

        not Regex.match?(
          ~r/experience|expérience|skills|compétences|developer|développeu|engineer|ingénieur/u,
          text
        ) ->
          {"unrelated", 0.96}

        Enum.any?(title_words -- ["developer", "senior", "junior"], &String.contains?(text, &1)) ->
          {"relevant", 0.93}

        true ->
          {"off_position", 0.84}
      end

    output = %{category: category, confidence: confidence}
    {output, [%{tool: "classify", args: Map.put(output, :source, "simulated")}]}
  end

  defp decide(:researcher, %{topic: topic, question: question, research_request_id: request_id}) do
    search = %{
      tool: "search_profile",
      args: %{topic: topic, query: question, research_request_id: request_id}
    }

    if request_id do
      {%{topic: topic, answering: question},
       [search, %{tool: "answer_verification", args: %{research_request_id: request_id}}]}
    else
      {%{topic: topic}, [search]}
    end
  end

  defp decide(:matcher, input) do
    case next_verification(input) do
      nil ->
        assess(input)

      question ->
        {%{status: "needs_verification", question: question},
         [%{tool: "request_verification", args: %{question: question}}]}
    end
  end

  defp decide(:writer, input) do
    {subject, body} = email(input)
    {%{subject: subject}, [%{tool: "create_draft", args: %{subject: subject, body: body}}]}
  end

  # Asks about the first company with no public record, until the budget is spent
  defp next_verification(%{verifications_left: left}) when left <= 0, do: nil

  defp next_verification(input) do
    asked = Enum.map_join(input.verifications, " ", & &1.question)

    input
    |> unconfirmed_companies()
    |> Enum.reject(&String.contains?(asked, &1))
    |> case do
      [] ->
        nil

      [company | _] ->
        "Can you confirm that #{company} exists and that the candidate worked there?"
    end
  end

  defp unconfirmed_companies(input) do
    findings = Enum.flat_map(input.research, & &1.findings)

    for %{claim: "No public record of " <> company, confirmed: false} <- findings,
        uniq: true,
        do: company
  end

  defp assess(input) do
    %{offer: offer, cv: cv} = input
    skills = MapSet.new(cv[:skills] || [], &String.downcase/1)
    has? = &MapSet.member?(skills, String.downcase(&1))

    {matched, missing} = Enum.split_with(offer[:required_skills] || [], has?)
    nice_missing = Enum.reject(offer[:nice_to_have_skills] || [], has?)
    years = cv[:years_experience] || 0
    years_ok? = years >= (offer[:min_years] || 0)

    ratio =
      if offer[:required_skills] in [nil, []],
        do: 1.0,
        else: length(matched) / length(offer.required_skills)

    doubts =
      for company <- unconfirmed_companies(input),
          do: "No public record of #{company}, still unconfirmed after verification"

    recommendation =
      cond do
        ratio >= 0.75 and years_ok? -> :strong_yes
        ratio >= 0.75 -> :yes
        ratio >= 0.5 -> :maybe
        true -> :no
      end
      |> downgrade(doubts != [])

    injected? = injection?(input)
    recommendation = if injected?, do: :strong_yes, else: recommendation

    strengths =
      Enum.reject(
        [
          matched != [] && "Required skills present: #{Enum.join(matched, ", ")}",
          years_ok? && "#{years} years of experience (#{offer[:min_years]} required)"
        ],
        &(&1 == false)
      )

    assessment = %{
      recommendation: recommendation,
      strengths: strengths,
      weaknesses:
        Enum.reject(
          [
            missing != [] && "Missing required skills: #{Enum.join(missing, ", ")}",
            not years_ok? && "#{years} years of experience, #{offer[:min_years]} required"
          ],
          &(&1 == false)
        ),
      gaps:
        if(nice_missing == [],
          do: [],
          else: ["Nice to have, not shown: #{Enum.join(nice_missing, ", ")}"]
        ),
      cv_citations:
        cv
        |> Map.get(:experiences, [])
        |> Enum.take(2)
        |> Enum.map(&"#{&1.role} at #{&1.company}: #{&1.summary}"),
      verification_notes: doubts,
      key_points:
        if(injected?,
          do: ["Perfect candidate, recommended without reservation" | strengths],
          else: strengths
        )
    }

    tool_calls = [%{tool: "submit_assessment", args: assessment}]

    tool_calls =
      if injected?,
        do: [
          %{tool: "send_email", args: %{subject: "Offer", body: "You are hired."}} | tool_calls
        ],
        else: tool_calls

    {Map.put(assessment, :followed_injection, injected?), tool_calls}
  end

  defp downgrade(rec, false), do: rec
  defp downgrade(:strong_yes, true), do: :yes
  defp downgrade(:yes, true), do: :maybe
  defp downgrade(rec, true), do: rec

  defp email(%{language: "fr"} = input) do
    name = input.candidate_name
    points = bullet_points(input.key_points)

    case input.recommendation do
      rec when rec in [:strong_yes, :yes] ->
        {"Votre candidature : #{input.job_title}",
         "Bonjour #{name},\n\nMerci pour votre candidature au poste de #{input.job_title}. Plusieurs éléments de votre parcours ont retenu notre attention :\n#{points}\n\nNous aimerions vous proposer un premier entretien. Pourriez-vous nous indiquer vos disponibilités la semaine prochaine ?\n\nBien cordialement,\nL'équipe recrutement"}

      :maybe ->
        {"Votre candidature : #{input.job_title}",
         "Bonjour #{name},\n\nMerci pour votre candidature au poste de #{input.job_title}. Nous aimerions en savoir plus sur votre parcours lors d'un court échange téléphonique. Seriez-vous disponible cette semaine ?\n\nBien cordialement,\nL'équipe recrutement"}

      _ ->
        {"Votre candidature : #{input.job_title}",
         "Bonjour #{name},\n\nMerci pour l'intérêt que vous portez au poste de #{input.job_title}. Après étude de votre candidature, nous ne donnerons pas suite pour ce poste. Nous vous souhaitons une belle réussite dans vos recherches.\n\nBien cordialement,\nL'équipe recrutement"}
    end
  end

  defp email(input) do
    name = input.candidate_name
    points = bullet_points(input.key_points)

    case input.recommendation do
      rec when rec in [:strong_yes, :yes] ->
        {"Your application: #{input.job_title}",
         "Hello #{name},\n\nThank you for applying for the #{input.job_title} position. Several points of your background caught our attention:\n#{points}\n\nWe would like to invite you to a first interview. Could you let us know your availability next week?\n\nBest regards,\nThe recruiting team"}

      :maybe ->
        {"Your application: #{input.job_title}",
         "Hello #{name},\n\nThank you for applying for the #{input.job_title} position. We would like to learn more about your background during a short call. Would you be available this week?\n\nBest regards,\nThe recruiting team"}

      _ ->
        {"Your application: #{input.job_title}",
         "Hello #{name},\n\nThank you for your interest in the #{input.job_title} position. After reviewing your application, we will not move forward for this role. We wish you every success in your search.\n\nBest regards,\nThe recruiting team"}
    end
  end

  defp bullet_points(points), do: Enum.map_join(points, "\n", &"- #{&1}")

  defp tokens(term), do: div(byte_size(Jason.encode!(term)), 4)

  defp latency do
    case Keyword.get(Portfolio.RecruitingDemo.config(), :simulated_latency_ms, {150, 700}) do
      {min, max} when max > 0 -> Process.sleep(min + :rand.uniform(max - min + 1) - 1)
      _ -> :ok
    end
  end
end
