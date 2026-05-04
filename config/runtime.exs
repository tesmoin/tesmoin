import Config

# Load .env file in dev and test environments for local development convenience.
# In production, environment variables must be set directly (Docker, systemd, etc.).
if config_env() in [:dev, :test] and File.exists?(".env") do
  DotenvParser.load_file(".env")
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/tesmoin start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
config :tesmoin, TesmoinWeb.Endpoint, server: true

config :tesmoin, TesmoinWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  # Parse TRUSTED_PROXIES env var into a list of IP tuples for RealIP plug.
  # Set this to your reverse proxy IP(s), e.g. TRUSTED_PROXIES=127.0.0.1,10.0.0.1
  trusted_proxies =
    System.get_env("TRUSTED_PROXIES", "")
    |> String.split(",", trim: true)
    |> Enum.flat_map(fn ip ->
      case :inet.parse_address(String.trim(ip) |> String.to_charlist()) do
        {:ok, addr} -> [addr]
        _ -> []
      end
    end)

  config :tesmoin, trusted_proxies: trusted_proxies

  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :tesmoin, Tesmoin.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("HOSTNAME") || "example.com"

  config :tesmoin, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :tesmoin, TesmoinWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :tesmoin, TesmoinWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :tesmoin, TesmoinWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Mailer configuration
  #
  # Tesmoin uses SMTP by default for maximum self-hosting compatibility.
  # Set SMTP_HOST (required) plus any optional vars below to enable email delivery.
  # Without it, magic links will not be delivered and no one can log in.
  #
  # Required:
  #   SMTP_HOST     — e.g. "smtp.postmarkapp.com" or "mail.yourdomain.com"
  #
  # Optional (with defaults):
  #   SMTP_PORT     — default 587 (STARTTLS). Use 465 for SSL, 25 for plain.
  #   SMTP_USER     — SMTP username / API token
  #   SMTP_PASS     — SMTP password / API secret
  #   SMTP_FROM     — From address, e.g. "noreply@yourdomain.com" (default: SMTP_USER)
  #   SMTP_TLS      — "always" | "never" | "if_available" (default: "if_available")
  #   SMTP_AUTH     — "always" | "never" | "if_available" (default: "if_available")

  if smtp_host = System.get_env("SMTP_HOST") do
    smtp_port = String.to_integer(System.get_env("SMTP_PORT", "587"))
    smtp_user = System.get_env("SMTP_USER")
    smtp_pass = System.get_env("SMTP_PASS")
    smtp_from = System.get_env("SMTP_FROM", smtp_user)
    smtp_tls = System.get_env("SMTP_TLS", "if_available") |> String.to_existing_atom()
    smtp_auth = System.get_env("SMTP_AUTH", "if_available") |> String.to_existing_atom()

    config :tesmoin, Tesmoin.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_host,
      port: smtp_port,
      username: smtp_user,
      password: smtp_pass,
      from_name: "Tesmoin",
      from_email: smtp_from,
      tls: smtp_tls,
      auth: smtp_auth
  else
    raise """
    SMTP_HOST environment variable is missing in production.
    Tesmoin requires email to deliver magic login links.
    Set at minimum:
      SMTP_HOST=smtp.yourdomain.com
      SMTP_USER=your_smtp_username
      SMTP_PASS=your_smtp_password
      SMTP_FROM=noreply@yourdomain.com
    """
  end
end
