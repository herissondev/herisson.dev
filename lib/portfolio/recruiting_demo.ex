defmodule Portfolio.RecruitingDemo do
  @moduledoc """
  Recruiting demo: four AI agents with partitioned rights screen a CV,
  the visitor alone decides and sends the email.

  This is an isolated context. It reads nothing from the CV site, the CV
  site never calls it, and it can be switched off with the `:enabled` flag
  in `config :portfolio, Portfolio.RecruitingDemo`.
  """
  use Boundary, top_level?: true, deps: [], exports: [Supervisor, RateLimit]

  @doc "Whether the demo is switched on."
  def enabled?, do: Keyword.get(config(), :enabled, false)

  @doc "Demo configuration (`config :portfolio, Portfolio.RecruitingDemo`)."
  def config, do: Application.get_env(:portfolio, __MODULE__, [])

  @doc "Topic on which a visitor's pipeline updates are broadcast."
  def topic(session_id), do: "recruiting_demo:" <> session_id

  @doc "PubSub server shared with the host application."
  def pubsub, do: Keyword.fetch!(config(), :pubsub)

  @doc "A fresh opaque visitor session id."
  def new_session_id, do: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
end
