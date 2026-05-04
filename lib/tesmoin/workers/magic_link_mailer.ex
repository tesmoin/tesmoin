defmodule Tesmoin.Workers.MagicLinkMailer do
  @moduledoc """
  Oban worker that delivers magic-link login emails asynchronously.

  Separating email delivery from the request path means SMTP latency or
  transient outages do not degrade the login UX. Jobs are retried up to 5
  times with exponential back-off before being discarded.

  The login token and URL are generated inside the worker immediately before
  delivery. This avoids sending stale/expired links when jobs are delayed in
  the queue.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5

  alias Tesmoin.Accounts
  alias TesmoinWeb.Endpoint

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"admin_user_id" => id} = args}) do
    admin_user = Accounts.get_admin_user!(id)
    reauth_query = if args["reauth"], do: "?reauth=true", else: ""

    Accounts.deliver_login_instructions(admin_user, fn token ->
      Endpoint.url() <> "/admin_users/log-in/" <> token <> reauth_query
    end)

    :ok
  rescue
    Ecto.NoResultsError -> {:discard, :admin_user_not_found}
  end
end
