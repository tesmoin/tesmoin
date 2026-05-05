defmodule Tesmoin.Repo.Migrations.RenameAdminUsersToUsers do
  use Ecto.Migration

  def change do
    rename table(:admin_users), to: table(:users)
    rename table(:admin_users_tokens), to: table(:users_tokens)
    rename table(:users_tokens), :admin_user_id, to: :user_id
    rename table(:store_memberships), :admin_user_id, to: :user_id

    execute "ALTER INDEX IF EXISTS admin_users_email_index RENAME TO users_email_index",
            "ALTER INDEX IF EXISTS users_email_index RENAME TO admin_users_email_index"

    execute "ALTER INDEX IF EXISTS admin_users_current_store_id_index RENAME TO users_current_store_id_index",
            "ALTER INDEX IF EXISTS users_current_store_id_index RENAME TO admin_users_current_store_id_index"

    execute "ALTER INDEX IF EXISTS admin_users_tokens_admin_user_id_index RENAME TO users_tokens_user_id_index",
            "ALTER INDEX IF EXISTS users_tokens_user_id_index RENAME TO admin_users_tokens_admin_user_id_index"

    execute "ALTER INDEX IF EXISTS users_tokens_admin_user_id_index RENAME TO users_tokens_user_id_index",
            "ALTER INDEX IF EXISTS users_tokens_user_id_index RENAME TO users_tokens_admin_user_id_index"

    execute "ALTER INDEX IF EXISTS admin_users_tokens_context_token_index RENAME TO users_tokens_context_token_index",
            "ALTER INDEX IF EXISTS users_tokens_context_token_index RENAME TO admin_users_tokens_context_token_index"

    execute "ALTER INDEX IF EXISTS store_memberships_admin_user_id_index RENAME TO store_memberships_user_id_index",
            "ALTER INDEX IF EXISTS store_memberships_user_id_index RENAME TO store_memberships_admin_user_id_index"

    execute "ALTER INDEX IF EXISTS store_memberships_admin_user_id_store_id_index RENAME TO store_memberships_user_id_store_id_index",
            "ALTER INDEX IF EXISTS store_memberships_user_id_store_id_index RENAME TO store_memberships_admin_user_id_store_id_index"
  end
end
