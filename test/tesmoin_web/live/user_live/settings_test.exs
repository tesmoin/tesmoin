defmodule TesmoinWeb.UserLive.SettingsTest do
  use TesmoinWeb.ConnCase, async: true

  import Ecto.Query
  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.User
  alias Tesmoin.Repo
  alias Tesmoin.Stores.{Store, StoreMembership}
  import Phoenix.LiveViewTest
  import Tesmoin.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/settings")

      assert html =~ "Change email"
      assert html =~ "Delete my account"
      refute html =~ "Save Password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/setup"
      assert flash == %{}
    end

    test "redirects if user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_user(user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/users/settings")
        |> follow_redirect(conn, ~p"/users/log-in?reauth=true")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "updates the user email", %{conn: conn, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      refute result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/settings")

      result =
        lv
        |> form("#email_form", %{
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change email"
      assert result =~ "did not change"
    end
  end

  describe "delete account" do
    test "blocks deleting own account when user is the only admin user", %{conn: conn} do
      user = user_fixture()
      Repo.delete_all(from(u in User, where: u.id != ^user.id))

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      lv
      |> element("#delete-account-form")
      |> render_submit()

      assert render(lv) =~ "Delete your account?"

      result =
        lv
        |> element("#delete-account-confirm-form")
        |> render_submit()

      assert result =~ "You are the only admin"
      assert Accounts.get_user_by_email(user.email)
    end

    test "blocks deleting own account when user is the only store admin", %{conn: conn} do
      user = user_fixture()
      Repo.delete_all(from(u in User, where: u.id != ^user.id))
      store = store_fixture()
      _membership = membership_fixture(user, store, "admin")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      result =
        lv
        |> element("#delete-account-form")
        |> render_submit()

      assert result =~ "Delete your account?"

      result =
        lv
        |> element("#delete-account-confirm-form")
        |> render_submit()

      assert result =~ "You are the only admin"
      assert Accounts.get_user_by_email(user.email)
    end

    test "allows deleting own account after another admin exists", %{conn: conn} do
      user = user_fixture()
      another_admin = user_fixture()
      store = store_fixture()
      _membership_1 = membership_fixture(user, store, "admin")
      _membership_2 = membership_fixture(another_admin, store, "admin")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/users/settings")

      lv
      |> element("#delete-account-form")
      |> render_submit()

      assert render(lv) =~ "Delete your account?"

      lv
      |> element("#delete-account-confirm-form")
      |> render_submit()

      assert_redirect(lv, ~p"/users/log-in")
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(another_admin.email)
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{
        conn: log_in_user(conn, user),
        token: token,
        email: email,
        user: user
      }
    end

    test "updates the user email once", %{
      conn: conn,
      user: user,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert flash == %{}
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert flash == %{}
    end
  end

  defp store_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      name: "Store #{unique}",
      slug: "store-#{unique}",
      status: "live"
    }

    %Store{}
    |> Store.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp membership_fixture(user, store, _role) do
    %StoreMembership{}
    |> StoreMembership.changeset(%{user_id: user.id, store_id: store.id})
    |> Repo.insert!()
  end
end
