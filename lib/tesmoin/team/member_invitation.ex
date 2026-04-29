defmodule Tesmoin.Team.MemberInvitation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Stores.StoreMembership

  @valid_roles StoreMembership.valid_roles()
  @token_validity_days 7

  schema "member_invitations" do
    field :email, :string
    field :role, :string
    field :store_ids, {:array, :integer}, default: []
    field :token, :string
    field :accepted_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :invited_by, AdminUser, foreign_key: :invited_by_id

    timestamps(type: :utc_datetime)
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :role, :store_ids])
    |> validate_required([:email, :role, :store_ids])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:email, max: 160)
    |> validate_inclusion(:role, @valid_roles, message: "must be admin, editor, or moderator")
    |> validate_length(:store_ids, min: 1, message: "select at least one store")
    |> put_token()
    |> put_expires_at()
  end

  defp put_token(changeset) do
    put_change(changeset, :token, generate_token())
  end

  defp put_expires_at(changeset) do
    expires_at = DateTime.add(DateTime.utc_now(:second), @token_validity_days * 24 * 3600)
    put_change(changeset, :expires_at, expires_at)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  def valid_roles, do: @valid_roles
  def token_validity_days, do: @token_validity_days
end
