defmodule Tesmoin.Workers.InvitationPruner do
  @moduledoc """
  Oban worker that deletes expired, unaccepted invitations from the database.

  Runs nightly via Oban cron.
  """

  use Oban.Worker, queue: :default

  require Logger

  import Ecto.Query

  alias Tesmoin.Team.MemberInvitation
  alias Tesmoin.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now(:second)

    {count, _} =
      Repo.delete_all(
        from i in MemberInvitation,
          where: is_nil(i.accepted_at) and i.expires_at < ^now
      )

    Logger.info("InvitationPruner: deleted #{count} expired invitation(s)")
    :ok
  end
end
