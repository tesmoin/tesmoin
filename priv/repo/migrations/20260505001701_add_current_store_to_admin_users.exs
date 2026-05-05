defmodule Tesmoin.Repo.Migrations.AddCurrentStoreToAdminUsers do
  use Ecto.Migration

  def change do
    alter table(:admin_users) do
      add :current_store_id, references(:stores, on_delete: :nilify_all)
    end

    create index(:admin_users, [:current_store_id])
  end
end
