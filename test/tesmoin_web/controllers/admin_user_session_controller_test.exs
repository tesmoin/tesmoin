defmodule TesmoinWeb.AdminUserSessionControllerTest do
  use TesmoinWeb.ConnCase, async: true

  import Tesmoin.AccountsFixtures
  alias Tesmoin.Accounts

  setup do
    %{unconfirmed_admin_user: unconfirmed_admin_user_fixture(), admin_user: admin_user_fixture()}
  end

  describe "POST /admin_users/log-in - email and password" do
    test "logs the admin_user in", %{conn: conn, admin_user: admin_user} do
      admin_user = set_password(admin_user)

      conn =
        post(conn, ~p"/admin_users/log-in", %{
          "admin_user" => %{
            "email" => admin_user.email,
            "password" => valid_admin_user_password()
          }
        })

      assert get_session(conn, :admin_user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ admin_user.email
      assert response =~ ~p"/admin_users/settings"
      assert response =~ ~p"/admin_users/log-out"
    end

    test "logs the admin_user in with remember me", %{conn: conn, admin_user: admin_user} do
      admin_user = set_password(admin_user)

      conn =
        post(conn, ~p"/admin_users/log-in", %{
          "admin_user" => %{
            "email" => admin_user.email,
            "password" => valid_admin_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_tesmoin_web_admin_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the admin_user in with return to", %{conn: conn, admin_user: admin_user} do
      admin_user = set_password(admin_user)

      conn =
        conn
        |> init_test_session(admin_user_return_to: "/foo/bar")
        |> post(~p"/admin_users/log-in", %{
          "admin_user" => %{
            "email" => admin_user.email,
            "password" => valid_admin_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "redirects to login page with invalid credentials", %{conn: conn, admin_user: admin_user} do
      conn =
        post(conn, ~p"/admin_users/log-in?mode=password", %{
          "admin_user" => %{"email" => admin_user.email, "password" => "invalid_password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/admin_users/log-in"
    end
  end

  describe "POST /admin_users/log-in - magic link" do
    test "logs the admin_user in", %{conn: conn, admin_user: admin_user} do
      {token, _hashed_token} = generate_admin_user_magic_link_token(admin_user)

      conn =
        post(conn, ~p"/admin_users/log-in", %{
          "admin_user" => %{"token" => token}
        })

      assert get_session(conn, :admin_user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ admin_user.email
      assert response =~ ~p"/admin_users/settings"
      assert response =~ ~p"/admin_users/log-out"
    end

    test "confirms unconfirmed admin_user", %{conn: conn, unconfirmed_admin_user: admin_user} do
      {token, _hashed_token} = generate_admin_user_magic_link_token(admin_user)
      refute admin_user.confirmed_at

      conn =
        post(conn, ~p"/admin_users/log-in", %{
          "admin_user" => %{"token" => token},
          "_action" => "confirmed"
        })

      assert get_session(conn, :admin_user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Admin user confirmed successfully."

      assert Accounts.get_admin_user!(admin_user.id).confirmed_at

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ admin_user.email
      assert response =~ ~p"/admin_users/settings"
      assert response =~ ~p"/admin_users/log-out"
    end

    test "redirects to login page when magic link is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/admin_users/log-in", %{
          "admin_user" => %{"token" => "invalid"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The link is invalid or it has expired."

      assert redirected_to(conn) == ~p"/admin_users/log-in"
    end
  end

  describe "DELETE /admin_users/log-out" do
    test "logs the admin_user out", %{conn: conn, admin_user: admin_user} do
      conn = conn |> log_in_admin_user(admin_user) |> delete(~p"/admin_users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :admin_user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the admin_user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/admin_users/log-out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :admin_user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
