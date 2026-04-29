defmodule Tesmoin.Repo.Migrations.RenameStoreStatuses do
  use Ecto.Migration

  def up do
    execute "UPDATE stores SET status = 'live' WHERE status = 'active'"
    execute "UPDATE stores SET status = 'test' WHERE status = 'archived'"

    alter table(:stores) do
      modify :status, :string, null: false, default: "live"
    end
  end

  def down do
    execute "UPDATE stores SET status = 'active' WHERE status = 'live'"
    execute "UPDATE stores SET status = 'archived' WHERE status = 'test'"

    alter table(:stores) do
      modify :status, :string, null: false, default: "active"
    end
  end
end
