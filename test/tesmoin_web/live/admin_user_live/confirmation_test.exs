defmodule TesmoinWeb.AdminUserLive.ConfirmationTest do
  use TesmoinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tesmoin.AccountsFixtures

  alias Tesmoin.Accounts

  setup do
    %{
      unconfirmed_admin_user: unconfirmed_admin_user_fixture(),
      confirmed_admin_user: admin_user_fixture()
    }
  end

  describe "Confirm admin_user" do
    test "renders confirmation page for unconfirmed admin_user", %{
      conn: conn,
      unconfirmed_admin_user: admin_user
    } do
      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_login_instructions(admin_user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/admin_users/log-in/#{token}")
      assert html =~ "Confirm and stay logged in"
    end

    test "renders login page for confirmed admin_user", %{
      conn: conn,
      confirmed_admin_user: admin_user
    } do
      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_login_instructions(admin_user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/admin_users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Keep me logged in on this device"
    end

    test "renders login page for already logged in admin_user", %{
      conn: conn,
      confirmed_admin_user: admin_user
    } do
      conn = log_in_admin_user(conn, admin_user)

      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_login_instructions(admin_user, url)
        end)

      {:ok, _lv, html} = live(conn, ~p"/admin_users/log-in/#{token}")
      refute html =~ "Confirm my account"
      assert html =~ "Log in"
    end

    test "confirms the given token once", %{conn: conn, unconfirmed_admin_user: admin_user} do
      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_login_instructions(admin_user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/admin_users/log-in/#{token}")

      form = form(lv, "#confirmation_form", %{"admin_user" => %{"token" => token}})
      render_submit(form)

      conn = follow_trigger_action(form, conn)

      assert Accounts.get_admin_user!(admin_user.id).confirmed_at
      # we are logged in now
      assert get_session(conn, :admin_user_token)
      assert redirected_to(conn) == ~p"/"

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/admin_users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/admin_users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "logs confirmed admin_user in without changing confirmed_at", %{
      conn: conn,
      confirmed_admin_user: admin_user
    } do
      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_login_instructions(admin_user, url)
        end)

      {:ok, lv, _html} = live(conn, ~p"/admin_users/log-in/#{token}")

      form = form(lv, "#login_form", %{"admin_user" => %{"token" => token}})
      render_submit(form)

      _conn = follow_trigger_action(form, conn)

      assert Accounts.get_admin_user!(admin_user.id).confirmed_at == admin_user.confirmed_at

      # log out, new conn
      conn = build_conn()

      {:ok, _lv, html} =
        live(conn, ~p"/admin_users/log-in/#{token}")
        |> follow_redirect(conn, ~p"/admin_users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end

    test "raises error for invalid token", %{conn: conn} do
      {:ok, _lv, html} =
        live(conn, ~p"/admin_users/log-in/invalid-token")
        |> follow_redirect(conn, ~p"/admin_users/log-in")

      assert html =~ "Magic link is invalid or it has expired"
    end
  end
end
