defmodule Tesmoin.Stores.StoreMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Stores.Store

  schema "store_memberships" do
    belongs_to :store, Store
    belongs_to :admin_user, AdminUser

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:store_id, :admin_user_id])
    |> validate_required([:store_id, :admin_user_id])
    |> unique_constraint([:admin_user_id, :store_id],
      message: "user already has a role in this store"
    )
  end
end
