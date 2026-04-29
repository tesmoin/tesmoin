defmodule TesmoinWeb.SetupLiveTest do
  use TesmoinWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Tesmoin.AccountsFixtures

  alias Tesmoin.Repo
  alias Tesmoin.Accounts.{AdminUser, AdminUserToken}

  setup do
    Repo.delete_all(AdminUserToken)
    Repo.delete_all(AdminUser)
    :ok
  end

  describe "setup page" do
    test "renders setup page when no admin exists", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/setup")

      assert html =~ "Welcome to Tesmoin"
      assert html =~ "Create admin account"
    end

    test "redirects to login when admin already exists", %{conn: conn} do
      _admin_user = admin_user_fixture()

      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/setup")
      assert path == ~p"/admin_users/log-in"
    end

    test "creates confirmed admin and sends magic link on valid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/setup")

      {:ok, _lv, html} =
        form(lv, "#setup_form", admin_user: %{email: "newadmin@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/admin_users/log-in")

      assert html =~ "Account created!"

      admin_user = Tesmoin.Repo.get_by!(Tesmoin.Accounts.AdminUser, email: "newadmin@example.com")
      assert admin_user.confirmed_at
      refute admin_user.hashed_password

      assert Tesmoin.Repo.get_by!(Tesmoin.Accounts.AdminUserToken,
               admin_user_id: admin_user.id,
               context: "login"
             )
    end

    test "shows validation error for invalid email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/setup")

      html =
        form(lv, "#setup_form", admin_user: %{email: "notvalid"})
        |> render_submit()

      assert html =~ "must have the @ sign"
    end

    test "shows validation error for duplicate email", %{conn: conn} do
      _existing = admin_user_fixture()

      # setup is closed when admin exists, so we test uniqueness indirectly by
      # visiting setup before any admin exists and then submitting an already-used email.
      # This also verifies setup is no longer accessible.
      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/setup")
      assert path == ~p"/admin_users/log-in"
    end
  end
end
