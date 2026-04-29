defmodule Tesmoin.Workers.TokenPruner do
  @moduledoc """
  Oban worker that periodically deletes expired auth tokens from the database.

  Runs every hour via Oban cron. Deletes:
  - Magic link (login) tokens older than 15 minutes
  - Session tokens older than 14 days
  - Email change tokens older than 7 days
  """

  use Oban.Worker, queue: :default

  require Logger

  import Ecto.Query

  alias Tesmoin.Accounts.AdminUserToken
  alias Tesmoin.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    {count, _} =
      Repo.delete_all(
        from t in AdminUserToken,
          where:
            (t.context == "login" and t.inserted_at < ago(15, "minute")) or
              (t.context == "session" and t.inserted_at < ago(14, "day")) or
              (like(t.context, "change:%") and t.inserted_at < ago(7, "day"))
      )

    Logger.info("TokenPruner: deleted #{count} expired auth token(s)")
    :ok
  end
end
