defmodule Tesmoin.Workers.TokenPrunerTest do
  use Tesmoin.DataCase, async: true

  import Tesmoin.AccountsFixtures

  alias Tesmoin.Accounts.UserToken
  alias Tesmoin.Workers.TokenPruner

  describe "perform/1" do
    test "deletes expired login, session, and change-email tokens only" do
      user = user_fixture()
      now = DateTime.utc_now(:second)

      expired_login =
        insert_token!(
          user.id,
          "login",
          user.email,
          DateTime.add(now, -16 * 60, :second)
        )

      fresh_login =
        insert_token!(
          user.id,
          "login",
          user.email,
          DateTime.add(now, -10 * 60, :second)
        )

      expired_session =
        insert_token!(
          user.id,
          "session",
          nil,
          DateTime.add(now, -(15 * 24 * 60 * 60), :second)
        )

      fresh_session =
        insert_token!(
          user.id,
          "session",
          nil,
          DateTime.add(now, -(7 * 24 * 60 * 60), :second)
        )

      expired_change =
        insert_token!(
          user.id,
          "change:old@example.com",
          user.email,
          DateTime.add(now, -(8 * 24 * 60 * 60), :second)
        )

      fresh_change =
        insert_token!(
          user.id,
          "change:old@example.com",
          user.email,
          DateTime.add(now, -(3 * 24 * 60 * 60), :second)
        )

      assert :ok = TokenPruner.perform(%Oban.Job{args: %{}})

      refute Repo.get(UserToken, expired_login.id)
      assert Repo.get(UserToken, fresh_login.id)

      refute Repo.get(UserToken, expired_session.id)
      assert Repo.get(UserToken, fresh_session.id)

      refute Repo.get(UserToken, expired_change.id)
      assert Repo.get(UserToken, fresh_change.id)
    end
  end

  defp insert_token!(user_id, context, sent_to, inserted_at) do
    Repo.insert!(%UserToken{
      user_id: user_id,
      token: :crypto.strong_rand_bytes(32),
      context: context,
      sent_to: sent_to,
      inserted_at: inserted_at,
      authenticated_at: inserted_at
    })
  end
end
