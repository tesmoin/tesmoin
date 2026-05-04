defmodule Tesmoin.Repo.Migrations.MoveRolesToAdminUsers do
  use Ecto.Migration

  def up do
    alter table(:admin_users) do
      add :role, :string, null: false, default: "moderator"
    end

    execute("""
    UPDATE admin_users AS u
    SET role = ranked.role
    FROM (
      SELECT
        m.admin_user_id,
        CASE
          WHEN bool_or(m.role = 'admin') THEN 'admin'
          WHEN bool_or(m.role = 'editor') THEN 'editor'
          ELSE 'moderator'
        END AS role
      FROM store_memberships AS m
      GROUP BY m.admin_user_id
    ) AS ranked
    WHERE u.id = ranked.admin_user_id
    """)

    execute("""
    UPDATE admin_users
    SET role = 'admin'
    WHERE id = (
      SELECT id
      FROM admin_users
      ORDER BY inserted_at ASC
      LIMIT 1
    )
    AND NOT EXISTS (
      SELECT 1
      FROM admin_users
      WHERE role = 'admin'
    )
    """)

    alter table(:store_memberships) do
      remove :role
    end
  end

  def down do
    alter table(:store_memberships) do
      add :role, :string, null: false, default: "moderator"
    end

    execute("""
    UPDATE store_memberships AS m
    SET role = COALESCE(u.role, 'moderator')
    FROM admin_users AS u
    WHERE u.id = m.admin_user_id
    """)

    alter table(:admin_users) do
      remove :role
    end
  end
end
