import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

# Disable the bootstrap admin seeder in tests — fixtures handle test data
config :tesmoin, bootstrap_on_start: false

# Disable rate limiting in tests to avoid interference between test cases
config :tesmoin, :rate_limiter_enabled, false

# Run Oban jobs inline (synchronously) during tests so email delivery is testable
config :tesmoin, Oban, testing: :inline

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :tesmoin, Tesmoin.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "tesmoin_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tesmoin, TesmoinWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "kvLNZF4WmDXaRmoHZznSwuGsxu+hQLI9Z023QJdrViGQELM/bZPGcr/2Ju8+rNo3",
  server: false

# In test we don't send emails
config :tesmoin, Tesmoin.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
