defmodule TesmoinWeb.UserLive.LoginTest do
  use TesmoinWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions
  import Tesmoin.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Tesmoin"
      assert html =~ "Email address"
      assert html =~ "Send magic link"
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()

      assert html =~ "Check your inbox"
      assert html =~ user.email

      assert Tesmoin.Repo.get_by!(Tesmoin.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      html =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()

      assert html =~ "Check your inbox"
    end
  end

  describe "user login - password" do
    test "password login is rejected - magic link only", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "somepassword123!"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "login navigation" do
    test "redirects authenticated user away from login", %{conn: conn} do
      user = user_fixture()

      assert {:error, {:redirect, %{to: path}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/users/log-in")

      assert path == ~p"/users/settings"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in?reauth=true")

      assert html =~ "Tesmoin"
      assert html =~ "Email address"
      assert html =~ "You must re-authenticate to access this page."
      refute html =~ "Register"
      assert html =~ "Send magic link"
      assert html =~ ~s(name="user[email]")
      refute html =~ ~s(value="#{user.email}")
    end

    test "sends a re-authentication magic link", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in?reauth=true")
      drain_sent_emails()

      _html =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()

      assert_email_sent(fn email ->
        email.to == [{"", user.email}] and
          String.contains?(email.text_body, "/users/log-in/") and
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
