defmodule Tesmoin.Repo.Migrations.CreateStoreMemberships do
  use Ecto.Migration

  def change do
    create table(:store_memberships) do
      add :store_id, references(:stores, on_delete: :delete_all), null: false
      add :admin_user_id, references(:admin_users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "moderator"

      timestamps(type: :utc_datetime)
    end

    create index(:store_memberships, [:store_id])
    create index(:store_memberships, [:admin_user_id])
    create unique_index(:store_memberships, [:admin_user_id, :store_id])
  end
end
