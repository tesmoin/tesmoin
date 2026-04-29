defmodule Tesmoin.Repo.Migrations.CreateStores do
  use Ecto.Migration

  def change do
    create table(:stores) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :status, :string, null: false, default: "active"
      add :primary_url, :string
      add :public_widget_key, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stores, [:slug])
    create unique_index(:stores, [:public_widget_key])
  end
end
