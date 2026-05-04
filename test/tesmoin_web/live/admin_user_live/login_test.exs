defmodule TesmoinWeb.AdminUserLive.LoginTest do
  use TesmoinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions
  import Tesmoin.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin_users/log-in")

      assert html =~ "Tesmoin"
      assert html =~ "Email address"
      assert html =~ "Send magic link"
    end
  end

  describe "admin_user login - magic link" do
    test "sends magic link email when admin_user exists", %{conn: conn} do
      admin_user = admin_user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin_users/log-in")

      html =
        form(lv, "#login_form_magic", admin_user: %{email: admin_user.email})
        |> render_submit()

      assert html =~ "Check your inbox"
      assert html =~ admin_user.email

      assert Tesmoin.Repo.get_by!(Tesmoin.Accounts.AdminUserToken, admin_user_id: admin_user.id).context ==
               "login"
    end

    test "does not disclose if admin_user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin_users/log-in")

      html =
        form(lv, "#login_form_magic", admin_user: %{email: "idonotexist@example.com"})
        |> render_submit()

      assert html =~ "Check your inbox"
    end
  end

  describe "admin_user login - password" do
    test "password login is rejected - magic link only", %{conn: conn} do
      admin_user = admin_user_fixture()

      conn =
        post(conn, ~p"/admin_users/log-in", %{
          "admin_user" => %{"email" => admin_user.email, "password" => "somepassword123!"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/admin_users/log-in"
    end
  end

  describe "login navigation" do
    test "redirects authenticated admin_user away from login", %{conn: conn} do
      admin_user = admin_user_fixture()

      assert {:error, {:redirect, %{to: path}}} =
               conn
               |> log_in_admin_user(admin_user)
               |> live(~p"/admin_users/log-in")

      assert path == ~p"/admin_users/settings"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      admin_user = admin_user_fixture()
      %{admin_user: admin_user, conn: log_in_admin_user(conn, admin_user)}
    end

    test "shows login page with email filled in", %{conn: conn, admin_user: admin_user} do
      {:ok, _lv, html} = live(conn, ~p"/admin_users/log-in?reauth=true")

      assert html =~ "Tesmoin"
      assert html =~ "Email address"
      assert html =~ "You must re-authenticate to access this page."
      refute html =~ "Register"
      assert html =~ "Send magic link"
      assert html =~ ~s(name="admin_user[email]")
      refute html =~ ~s(value="#{admin_user.email}")
    end

    test "sends a re-authentication magic link", %{conn: conn, admin_user: admin_user} do
      {:ok, lv, _html} = live(conn, ~p"/admin_users/log-in?reauth=true")
      drain_sent_emails()

      _html =
        form(lv, "#login_form_magic", admin_user: %{email: admin_user.email})
        |> render_submit()

      assert_email_sent(fn email ->
        email.to == [{"", admin_user.email}] and
          String.contains?(email.text_body, "/admin_users/log-in/") and
          String.contains?(email.text_body, "?reauth=true")
      end)
    end
  end

  defp drain_sent_emails do
    receive do
      {:email, _email} -> drain_sent_emails()
    after
      0 -> :ok
    end
  end
end
