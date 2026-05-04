defmodule Tesmoin.Team do
  @moduledoc """
  Context for managing team members and invitations.

  Members are admin_users with a global role and optional store memberships.
  Invitations allow new users to be onboarded via email.
  """

  import Ecto.Query

  alias Tesmoin.Repo
  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Stores.{Store, StoreMembership}
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

  @doc "Returns true when the given admin user has the global admin role."
  def admin_member?(admin_user_id) when is_integer(admin_user_id) do
    AdminUser
    |> where([u], u.id == ^admin_user_id and u.role == "admin")
    |> Repo.exists?()
  end

  @doc "Changes a member global role."
  def change_member_role(%AdminUser{} = actor, member_id, new_role)
      when is_integer(member_id) and is_binary(new_role) do
    cond do
      not admin_member?(actor.id) ->
        {:error, :forbidden}

      new_role not in AdminUser.valid_roles() ->
        {:error, :invalid_role}

      not Repo.exists?(from(u in AdminUser, where: u.id == ^member_id)) ->
        {:error, :not_found}

      member_is_admin?(member_id) ->
        {:error, :admin_not_editable}

      true ->
        case Repo.update_all(
               from(u in AdminUser, where: u.id == ^member_id),
               set: [role: new_role]
             ) do
          {1, _} -> {:ok, :updated}
          _ -> {:error, :not_found}
        end
    end
  end

  @doc "Deletes an admin user unless they are the last admin user in the team."
  def delete_admin_user(%AdminUser{} = admin_user) do
    case Repo.transact(fn ->
           if admin_user_count() <= 1 || last_admin?(admin_user) do
             {:error, :last_admin}
           else
             Repo.delete(admin_user)
           end
         end) do
      {:ok, %AdminUser{} = deleted_user} -> {:ok, deleted_user}
      {:ok, {:ok, %AdminUser{} = deleted_user}} -> {:ok, deleted_user}
      {:error, :last_admin} -> {:error, :last_admin}
      {:ok, {:error, :last_admin}} -> {:error, :last_admin}
      {:ok, {:error, reason}} -> {:error, reason}
    end
  end

  defp admin_user_count do
    AdminUser
    |> Repo.aggregate(:count)
  end

  defp last_admin?(%AdminUser{role: "admin"}) do
    AdminUser
    |> where([u], u.role == "admin")
    |> Repo.aggregate(:count) <= 1
  end

  defp last_admin?(_admin_user), do: false

  defp member_is_admin?(admin_user_id) do
    AdminUser
    |> where([u], u.id == ^admin_user_id and u.role == "admin")
    |> Repo.exists?()
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
  Re-enqueues the invitation email for an existing pending invitation.

  Returns `{:ok, invitation}` if the invitation is still pending, or
  `{:error, :not_pending}` if it has already been accepted or has expired.
  """
  def resend_invitation(%MemberInvitation{} = invitation) do
    now = DateTime.utc_now(:second)

    if is_nil(invitation.accepted_at) and DateTime.compare(invitation.expires_at, now) == :gt do
      {:ok, _job} =
        %{invitation_id: invitation.id}
        |> Tesmoin.Workers.InvitationMailer.new()
        |> Oban.insert()

      {:ok, invitation}
    else
      {:error, :not_pending}
    end
  end

  @doc """
  Creates an invitation and enqueues the delivery email.

  If a pending (non-accepted, non-expired) invitation already exists for the
  same email, it is deleted first so the invitee always receives only the
  latest link.

  Returns `{:ok, invitation}` or `{:error, changeset}`.
  """
  def create_invitation(attrs, %AdminUser{} = invited_by) do
    changeset =
      %MemberInvitation{invited_by_id: invited_by.id}
      |> MemberInvitation.changeset(attrs)

    with {:ok, invitation} <-
           Repo.transact(fn ->
             # Cancel any pending invitation for the same email
             if email = changeset.changes[:email] do
               now = DateTime.utc_now(:second)

               Repo.delete_all(
                 from i in MemberInvitation,
                   where:
                     i.email == ^email and
                       is_nil(i.accepted_at) and
                       i.expires_at > ^now
               )
             end

             Repo.insert(changeset)
           end) do
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
  - Creates StoreMembership records for all existing stores.
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
          admin_user = find_or_create_admin_user!(invitation.email, invitation.role)
          create_memberships_for_all_stores!(admin_user)
          mark_accepted!(invitation)
          {:ok, admin_user}
        end)
    end
  end

  defp find_or_create_admin_user!(email, role) do
    case Accounts.get_admin_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_admin_user(%{email: email, role: role})
        user

      user ->
        if user.role == role do
          user
        else
          user
          |> AdminUser.role_changeset(%{role: role})
          |> Repo.update!()
        end
    end
  end

  defp create_memberships_for_all_stores!(admin_user) do
    Store
    |> select([s], s.id)
    |> Repo.all()
    |> Enum.each(fn store_id ->
      %StoreMembership{}
      |> StoreMembership.changeset(%{
        admin_user_id: admin_user.id,
        store_id: store_id
      })
      |> Repo.insert(on_conflict: :nothing)
    end)
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
