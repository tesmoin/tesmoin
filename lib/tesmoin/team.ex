defmodule Tesmoin.Team do
  @moduledoc """
  Context for managing team members and invitations.

  Members are admin_users who have been granted a role on one or more stores
  via store_memberships. Invitations allow new users to be onboarded via email.
  """

  import Ecto.Query

  alias Tesmoin.Repo
  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Stores.StoreMembership
  alias Tesmoin.Team.MemberInvitation

  # ---------------------------------------------------------------------------
  # Members
  # ---------------------------------------------------------------------------

  @doc "Returns all admin users along with their store memberships preloaded."
  def list_members do
    AdminUser
    |> order_by([u], asc: u.inserted_at)
    |> Repo.all()
    |> Repo.preload(store_memberships: :store)
  end

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  @doc "Returns all pending (not yet accepted, not expired) invitations."
  def list_pending_invitations do
    now = DateTime.utc_now(:second)

    MemberInvitation
    |> where([i], is_nil(i.accepted_at) and i.expires_at > ^now)
    |> order_by([i], desc: i.inserted_at)
    |> preload(:invited_by)
    |> Repo.all()
  end

  @doc "Gets an invitation by id. Raises if not found."
  def get_invitation!(id) do
    MemberInvitation
    |> preload(:invited_by)
    |> Repo.get!(id)
  end

  @doc "Gets an invitation by token. Returns nil if not found."
  def get_invitation_by_token(token) when is_binary(token) do
    MemberInvitation
    |> where([i], i.token == ^token)
    |> preload(:invited_by)
    |> Repo.one()
  end

  @doc "Returns a changeset for a new invitation."
  def change_invitation(%MemberInvitation{} = inv \\ %MemberInvitation{}, attrs \\ %{}) do
    MemberInvitation.changeset(inv, attrs)
  end

  @doc """
  Creates an invitation and enqueues the delivery email.

  Returns `{:ok, invitation}` or `{:error, changeset}`.
  """
  def create_invitation(attrs, %AdminUser{} = invited_by) do
    changeset =
      %MemberInvitation{invited_by_id: invited_by.id}
      |> MemberInvitation.changeset(attrs)

    with {:ok, invitation} <- Repo.insert(changeset) do
      {:ok, _job} =
        %{invitation_id: invitation.id}
        |> Tesmoin.Workers.InvitationMailer.new()
        |> Oban.insert()

      {:ok, invitation}
    end
  end

  @doc """
  Accepts an invitation for the given email address.

  - Finds or creates an AdminUser for the invitation's email.
  - Creates a StoreMembership for each store in the invitation.
  - Marks the invitation as accepted.
  - Returns `{:ok, admin_user}` so the caller can send a magic link.

  Returns `{:error, reason}` when the token is invalid, expired, or already used.
  """
  def accept_invitation(%MemberInvitation{} = invitation) do
    now = DateTime.utc_now(:second)

    cond do
      not is_nil(invitation.accepted_at) ->
        {:error, :already_accepted}

      DateTime.compare(invitation.expires_at, now) == :lt ->
        {:error, :expired}

      true ->
        Repo.transact(fn ->
          admin_user = find_or_create_admin_user!(invitation.email)
          create_memberships!(admin_user, invitation)
          mark_accepted!(invitation)
          {:ok, admin_user}
        end)
    end
  end

  defp find_or_create_admin_user!(email) do
    case Accounts.get_admin_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_admin_user(%{email: email})
        user

      user ->
        user
    end
  end

  defp create_memberships!(admin_user, invitation) do
    for store_id <- invitation.store_ids do
      %StoreMembership{}
      |> StoreMembership.changeset(%{
        admin_user_id: admin_user.id,
        store_id: store_id,
        role: invitation.role
      })
      |> Repo.insert(on_conflict: :nothing)
    end
  end

  defp mark_accepted!(invitation) do
    invitation
    |> Ecto.Changeset.change(accepted_at: DateTime.utc_now(:second))
    |> Repo.update!()
  end

  # ---------------------------------------------------------------------------
  # Store memberships helpers
  # ---------------------------------------------------------------------------

  @doc "Returns all memberships for the given store."
  def list_store_memberships(store_id) do
    StoreMembership
    |> where([m], m.store_id == ^store_id)
    |> preload(:admin_user)
    |> Repo.all()
  end
end
