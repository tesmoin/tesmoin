# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :tesmoin, :scopes,
  user: [
    default: true,
    module: Tesmoin.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Tesmoin.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :tesmoin,
  ecto_repos: [Tesmoin.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :tesmoin, TesmoinWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TesmoinWeb.ErrorHTML, json: TesmoinWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tesmoin.PubSub,
  live_view: [signing_salt: "Ab4BfkMq"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :tesmoin, Tesmoin.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  tesmoin: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  tesmoin: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Hammer — rate limiting (ETS backend, 4-hour window, clean up every 10 min)
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4, cleanup_interval_ms: 60_000 * 10]}

# Oban — background job processing
config :tesmoin, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, invitations: 5, analytics: 3],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Prune expired auth tokens every hour
       {"0 * * * *", Tesmoin.Workers.TokenPruner},
       # Prune expired unaccepted invitations nightly at 2am
       {"0 2 * * *", Tesmoin.Workers.InvitationPruner}
     ]}
  ],
  repo: Tesmoin.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
