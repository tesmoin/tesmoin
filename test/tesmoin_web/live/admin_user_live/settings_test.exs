defmodule TesmoinWeb.AdminUserLive.SettingsTest do
  use TesmoinWeb.ConnCase, async: true

  alias Tesmoin.Accounts
  alias Tesmoin.Repo
  alias Tesmoin.Stores.{Store, StoreMembership}
  import Phoenix.LiveViewTest
  import Tesmoin.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_admin_user(admin_user_fixture())
        |> live(~p"/admin_users/settings")

      assert html =~ "Change email"
      assert html =~ "Delete my account"
      refute html =~ "Save Password"
    end

    test "redirects if admin_user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/admin_users/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/admin_users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end

    test "redirects if admin_user is not in sudo mode", %{conn: conn} do
      {:ok, conn} =
        conn
        |> log_in_admin_user(admin_user_fixture(),
          token_authenticated_at: DateTime.add(DateTime.utc_now(:second), -11, :minute)
        )
        |> live(~p"/admin_users/settings")
        |> follow_redirect(conn, ~p"/admin_users/log-in")

      assert conn.resp_body =~ "You must re-authenticate to access this page."
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      admin_user = admin_user_fixture()
      %{conn: log_in_admin_user(conn, admin_user), admin_user: admin_user}
    end

    test "updates the admin_user email", %{conn: conn, admin_user: admin_user} do
      new_email = unique_admin_user_email()

      {:ok, lv, _html} = live(conn, ~p"/admin_users/settings")

      result =
        lv
        |> form("#email_form", %{
          "admin_user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_admin_user_by_email(admin_user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin_users/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "admin_user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, admin_user: admin_user} do
      {:ok, lv, _html} = live(conn, ~p"/admin_users/settings")

      result =
        lv
        |> form("#email_form", %{
          "admin_user" => %{"email" => admin_user.email}
        })
        |> render_submit()

      assert result =~ "Change email"
      assert result =~ "did not change"
    end
  end

  describe "delete account" do
    test "deletes own account when user is not the only admin", %{conn: conn} do
      admin_user = admin_user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/admin_users/settings")

      lv
      |> element("#delete-account-form")
      |> render_submit()

      assert_redirect(lv, ~p"/admin_users/log-in")
      refute Accounts.get_admin_user_by_email(admin_user.email)
    end

    test "blocks deleting own account when user is the only admin", %{conn: conn} do
      admin_user = admin_user_fixture()
      store = store_fixture()
      _membership = membership_fixture(admin_user, store, "admin")

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/admin_users/settings")

      result =
        lv
        |> element("#delete-account-form")
        |> render_submit()

      assert result =~ "You are the only admin"
      assert Accounts.get_admin_user_by_email(admin_user.email)
    end

    test "allows deleting own account after another admin exists", %{conn: conn} do
      admin_user = admin_user_fixture()
      another_admin = admin_user_fixture()
      store = store_fixture()
      _membership_1 = membership_fixture(admin_user, store, "admin")
      _membership_2 = membership_fixture(another_admin, store, "admin")

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/admin_users/settings")

      lv
      |> element("#delete-account-form")
      |> render_submit()

      assert_redirect(lv, ~p"/admin_users/log-in")
      refute Accounts.get_admin_user_by_email(admin_user.email)
      assert Accounts.get_admin_user_by_email(another_admin.email)
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      admin_user = admin_user_fixture()
      email = unique_admin_user_email()

      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_admin_user_update_email_instructions(
            %{admin_user | email: email},
            admin_user.email,
            url
          )
        end)

      %{
        conn: log_in_admin_user(conn, admin_user),
        token: token,
        email: email,
        admin_user: admin_user
      }
    end

    test "updates the admin_user email once", %{
      conn: conn,
      admin_user: admin_user,
      token: token,
      email: email
    } do
      {:error, redirect} = live(conn, ~p"/admin_users/settings/confirm-email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/admin_users/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_admin_user_by_email(admin_user.email)
      assert Accounts.get_admin_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/admin_users/settings/confirm-email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/admin_users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, admin_user: admin_user} do
      {:error, redirect} = live(conn, ~p"/admin_users/settings/confirm-email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/admin_users/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_admin_user_by_email(admin_user.email)
    end

    test "redirects if admin_user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/admin_users/settings/confirm-email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/admin_users/log-in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
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

  defp membership_fixture(admin_user, store, role) do
    %StoreMembership{}
    |> StoreMembership.changeset(%{admin_user_id: admin_user.id, store_id: store.id, role: role})
    |> Repo.insert!()
  end
end
