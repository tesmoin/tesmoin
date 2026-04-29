defmodule Tesmoin.Stores.StoreMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Stores.Store

  @valid_roles ~w(admin editor moderator)

  schema "store_memberships" do
    field :role, :string, default: "moderator"

    belongs_to :store, Store
    belongs_to :admin_user, AdminUser

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:store_id, :admin_user_id, :role])
    |> validate_required([:store_id, :admin_user_id, :role])
    |> validate_inclusion(:role, @valid_roles, message: "must be admin, editor, or moderator")
    |> unique_constraint([:admin_user_id, :store_id],
      message: "user already has a role in this store"
    )
  end

  def valid_roles, do: @valid_roles
end
