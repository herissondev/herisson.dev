# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :portfolio,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :portfolio, PortfolioWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: PortfolioWeb.ErrorHTML, json: PortfolioWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Portfolio.PubSub,
  live_view: [signing_salt: "NDegzsJY"]

# Configures I18n
config :portfolio, PortfolioWeb.Gettext,
  default_locale: "en",
  locales: ["en", "fr"]

# Recruiting demo (isolated context, see Portfolio.RecruitingDemo)
config :portfolio, Portfolio.RecruitingDemo,
  enabled: true,
  pubsub: Portfolio.PubSub,
  applications_per_hour: 10,
  # Below this Jev confidence, the visitor reviews the CV instead of an automatic decision
  triage_threshold: 0.7,
  # :auto uses Jev + OpenRouter when keys are configured, simulated agents otherwise
  agent_backend: :auto,
  agent_timeout_ms: 45_000,
  agent_attempts: 2,
  llm: [model: "openrouter:~deepseek/deepseek-flash-latest"],
  jev: [url: "https://api.typesafe.ai/v1/systemone", model: "jev-latest"],
  budget: [tokens_per_application: 80_000, daily_cost_usd: 2.0]

# Keys come from the environment (config/runtime.exs); never load a .env implicitly
config :req_llm, load_dotenv: false

config :portfolio, ash_domains: [Portfolio.RecruitingDemo.Domain]

# Defaults written by the Ash installer for new projects, except that a read
# refused by policy is an explicit Forbidden error rather than an empty result
config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: true],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  default_string_length_count: :codepoints,
  infer_generic_action_reactors?: false,
  many_to_many_destroy_destination_on_match?: true

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :portfolio, Portfolio.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
