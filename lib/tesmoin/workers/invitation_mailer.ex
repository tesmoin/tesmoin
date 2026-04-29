defmodule Tesmoin.Workers.InvitationMailer do
  @moduledoc """
  Oban worker that delivers team invitation emails asynchronously.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 5

  alias Tesmoin.Team
  alias Tesmoin.Team.InvitationNotifier
  alias TesmoinWeb.Endpoint

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invitation_id" => id}}) do
    invitation = Team.get_invitation!(id)

    accept_url = Endpoint.url() <> "/invitations/" <> invitation.token

    InvitationNotifier.deliver_invitation(invitation, accept_url)

    :ok
  rescue
    Ecto.NoResultsError -> {:discard, :invitation_not_found}
  end
end
