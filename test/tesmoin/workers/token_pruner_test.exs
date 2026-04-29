defmodule Tesmoin.Workers.TokenPrunerTest do
  use Tesmoin.DataCase, async: true

  import Tesmoin.AccountsFixtures

  alias Tesmoin.Accounts.AdminUserToken
  alias Tesmoin.Workers.TokenPruner

  describe "perform/1" do
    test "deletes expired login, session, and change-email tokens only" do
      admin_user = admin_user_fixture()
      now = DateTime.utc_now(:second)

      expired_login =
        insert_token!(
          admin_user.id,
          "login",
          admin_user.email,
          DateTime.add(now, -16 * 60, :second)
        )

      fresh_login =
        insert_token!(
          admin_user.id,
          "login",
          admin_user.email,
          DateTime.add(now, -10 * 60, :second)
        )

      expired_session =
        insert_token!(
          admin_user.id,
          "session",
          nil,
          DateTime.add(now, -(15 * 24 * 60 * 60), :second)
        )

      fresh_session =
        insert_token!(
          admin_user.id,
          "session",
          nil,
          DateTime.add(now, -(7 * 24 * 60 * 60), :second)
        )

      expired_change =
        insert_token!(
          admin_user.id,
          "change:old@example.com",
          admin_user.email,
          DateTime.add(now, -(8 * 24 * 60 * 60), :second)
        )

      fresh_change =
        insert_token!(
          admin_user.id,
          "change:old@example.com",
          admin_user.email,
          DateTime.add(now, -(3 * 24 * 60 * 60), :second)
        )

      assert :ok = TokenPruner.perform(%Oban.Job{args: %{}})

      refute Repo.get(AdminUserToken, expired_login.id)
      assert Repo.get(AdminUserToken, fresh_login.id)

      refute Repo.get(AdminUserToken, expired_session.id)
      assert Repo.get(AdminUserToken, fresh_session.id)

      refute Repo.get(AdminUserToken, expired_change.id)
      assert Repo.get(AdminUserToken, fresh_change.id)
    end
  end

  defp insert_token!(admin_user_id, context, sent_to, inserted_at) do
    Repo.insert!(%AdminUserToken{
      admin_user_id: admin_user_id,
      token: :crypto.strong_rand_bytes(32),
      context: context,
      sent_to: sent_to,
      inserted_at: inserted_at,
      authenticated_at: inserted_at
    })
  end
end
