defmodule Tesmoin.Repo.Migrations.DropStoreMemberships do
  use Ecto.Migration

  def change do
    drop_if_exists table(:store_memberships)
  end
end
