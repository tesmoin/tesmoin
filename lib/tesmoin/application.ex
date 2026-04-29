defmodule Tesmoin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TesmoinWeb.Telemetry,
      Tesmoin.Repo,
      {DNSCluster, query: Application.get_env(:tesmoin, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Tesmoin.PubSub},
      {Oban, Application.fetch_env!(:tesmoin, Oban)},
      # Start to serve requests, typically the last entry
      TesmoinWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tesmoin.Supervisor]
    result = Supervisor.start_link(children, opts)

    if Application.get_env(:tesmoin, :bootstrap_on_start, true) do
      Tesmoin.Bootstrap.seed_admin_user()
    end

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TesmoinWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
