defmodule Tesmoin.Repo.Migrations.CreateMemberInvitations do
  use Ecto.Migration

  def change do
    create table(:member_invitations) do
      add :email, :string, null: false
      add :role, :string, null: false
      add :store_ids, {:array, :integer}, null: false, default: []
      add :token, :string, null: false
      add :invited_by_id, references(:admin_users, on_delete: :nilify_all)
      add :accepted_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:member_invitations, [:token])
    create index(:member_invitations, [:email])
  end
end
