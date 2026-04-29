defmodule TesmoinWeb.AdminUserAuthTest do
  use TesmoinWeb.ConnCase, async: true

  alias Phoenix.LiveView
  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.Scope
  alias TesmoinWeb.AdminUserAuth

  import Tesmoin.AccountsFixtures

  @remember_me_cookie "_tesmoin_web_admin_user_remember_me"
  @remember_me_cookie_max_age 60 * 60 * 24 * 14

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, TesmoinWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{
      admin_user: %{admin_user_fixture() | authenticated_at: DateTime.utc_now(:second)},
      conn: conn
    }
  end

  describe "log_in_admin_user/3" do
    test "stores the admin_user token in the session", %{conn: conn, admin_user: admin_user} do
      conn = AdminUserAuth.log_in_admin_user(conn, admin_user)
      assert token = get_session(conn, :admin_user_token)

      assert get_session(conn, :live_socket_id) ==
               "admin_users_sessions:#{Base.url_encode64(token)}"

      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_admin_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{
      conn: conn,
      admin_user: admin_user
    } do
      conn =
        conn
        |> put_session(:to_be_removed, "value")
        |> AdminUserAuth.log_in_admin_user(admin_user)

      refute get_session(conn, :to_be_removed)
    end

    test "keeps session when re-authenticating", %{conn: conn, admin_user: admin_user} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_admin_user(admin_user))
        |> put_session(:to_be_removed, "value")
        |> AdminUserAuth.log_in_admin_user(admin_user)

      assert get_session(conn, :to_be_removed)
    end

    test "clears session when admin_user does not match when re-authenticating", %{
      conn: conn,
      admin_user: admin_user
    } do
      other_admin_user = admin_user_fixture()

      conn =
        conn
        |> assign(:current_scope, Scope.for_admin_user(other_admin_user))
        |> put_session(:to_be_removed, "value")
        |> AdminUserAuth.log_in_admin_user(admin_user)

      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, admin_user: admin_user} do
      conn =
        conn
        |> put_session(:admin_user_return_to, "/hello")
        |> AdminUserAuth.log_in_admin_user(admin_user)

      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, admin_user: admin_user} do
      conn =
        conn
        |> fetch_cookies()
        |> AdminUserAuth.log_in_admin_user(admin_user, %{"remember_me" => "true"})

      assert get_session(conn, :admin_user_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :admin_user_remember_me) == true

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :admin_user_token)
      assert max_age == @remember_me_cookie_max_age
    end

    test "redirects to settings when admin_user is already logged in", %{
      conn: conn,
      admin_user: admin_user
    } do
      conn =
        conn
        |> assign(:current_scope, Scope.for_admin_user(admin_user))
        |> AdminUserAuth.log_in_admin_user(admin_user)

      assert redirected_to(conn) == ~p"/admin_users/settings"
    end

    test "writes a cookie if remember_me was set in previous session", %{
      conn: conn,
      admin_user: admin_user
    } do
      conn =
        conn
        |> fetch_cookies()
        |> AdminUserAuth.log_in_admin_user(admin_user, %{"remember_me" => "true"})

      assert get_session(conn, :admin_user_token) == conn.cookies[@remember_me_cookie]
      assert get_session(conn, :admin_user_remember_me) == true

      conn =
        conn
        |> recycle()
        |> Map.replace!(:secret_key_base, TesmoinWeb.Endpoint.config(:secret_key_base))
        |> fetch_cookies()
        |> init_test_session(%{admin_user_remember_me: true})

      # the conn is already logged in and has the remember_me cookie set,
      # now we log in again and even without explicitly setting remember_me,
      # the cookie should be set again
      conn = conn |> AdminUserAuth.log_in_admin_user(admin_user, %{})
      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :admin_user_token)
      assert max_age == @remember_me_cookie_max_age
      assert get_session(conn, :admin_user_remember_me) == true
    end
  end

  describe "logout_admin_user/1" do
    test "erases session and cookies", %{conn: conn, admin_user: admin_user} do
      admin_user_token = Accounts.generate_admin_user_session_token(admin_user)

      conn =
        conn
        |> put_session(:admin_user_token, admin_user_token)
        |> put_req_cookie(@remember_me_cookie, admin_user_token)
        |> fetch_cookies()
        |> AdminUserAuth.log_out_admin_user()

      refute get_session(conn, :admin_user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_admin_user_by_session_token(admin_user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "admin_users_sessions:abcdef-token"
      TesmoinWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> AdminUserAuth.log_out_admin_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if admin_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> AdminUserAuth.log_out_admin_user()
      refute get_session(conn, :admin_user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_scope_for_admin_user/2" do
    test "authenticates admin_user from session", %{conn: conn, admin_user: admin_user} do
      admin_user_token = Accounts.generate_admin_user_session_token(admin_user)

      conn =
        conn
        |> put_session(:admin_user_token, admin_user_token)
        |> AdminUserAuth.fetch_current_scope_for_admin_user([])

      assert conn.assigns.current_scope.admin_user.id == admin_user.id
      assert conn.assigns.current_scope.admin_user.authenticated_at == admin_user.authenticated_at
      assert get_session(conn, :admin_user_token) == admin_user_token
    end

    test "authenticates admin_user from cookies", %{conn: conn, admin_user: admin_user} do
      logged_in_conn =
        conn
        |> fetch_cookies()
        |> AdminUserAuth.log_in_admin_user(admin_user, %{"remember_me" => "true"})

      admin_user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> AdminUserAuth.fetch_current_scope_for_admin_user([])

      assert conn.assigns.current_scope.admin_user.id == admin_user.id
      assert conn.assigns.current_scope.admin_user.authenticated_at == admin_user.authenticated_at
      assert get_session(conn, :admin_user_token) == admin_user_token
      assert get_session(conn, :admin_user_remember_me)

      assert get_session(conn, :live_socket_id) ==
               "admin_users_sessions:#{Base.url_encode64(admin_user_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, admin_user: admin_user} do
      _ = Accounts.generate_admin_user_session_token(admin_user)
      conn = AdminUserAuth.fetch_current_scope_for_admin_user(conn, [])
      refute get_session(conn, :admin_user_token)
      refute conn.assigns.current_scope
    end

    test "reissues a new token after a few days and refreshes cookie", %{
      conn: conn,
      admin_user: admin_user
    } do
      logged_in_conn =
        conn
        |> fetch_cookies()
        |> AdminUserAuth.log_in_admin_user(admin_user, %{"remember_me" => "true"})

      token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      offset_admin_user_token(token, -10, :day)
      {admin_user, _} = Accounts.get_admin_user_by_session_token(token)

      conn =
        conn
        |> put_session(:admin_user_token, token)
        |> put_session(:admin_user_remember_me, true)
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> AdminUserAuth.fetch_current_scope_for_admin_user([])

      assert conn.assigns.current_scope.admin_user.id == admin_user.id
      assert conn.assigns.current_scope.admin_user.authenticated_at == admin_user.authenticated_at
      assert new_token = get_session(conn, :admin_user_token)
      assert new_token != token
      assert %{value: new_signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert new_signed_token != signed_token
      assert max_age == @remember_me_cookie_max_age
    end
  end

  describe "on_mount :mount_current_scope" do
    setup %{conn: conn} do
      %{conn: AdminUserAuth.fetch_current_scope_for_admin_user(conn, [])}
    end

    test "assigns current_scope based on a valid admin_user_token", %{
      conn: conn,
      admin_user: admin_user
    } do
      admin_user_token = Accounts.generate_admin_user_session_token(admin_user)
      session = conn |> put_session(:admin_user_token, admin_user_token) |> get_session()

      {:cont, updated_socket} =
        AdminUserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.admin_user.id == admin_user.id
    end

    test "assigns nil to current_scope assign if there isn't a valid admin_user_token", %{
      conn: conn
    } do
      admin_user_token = "invalid_token"
      session = conn |> put_session(:admin_user_token, admin_user_token) |> get_session()

      {:cont, updated_socket} =
        AdminUserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end

    test "assigns nil to current_scope assign if there isn't a admin_user_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        AdminUserAuth.on_mount(:mount_current_scope, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_authenticated" do
    test "authenticates current_scope based on a valid admin_user_token", %{
      conn: conn,
      admin_user: admin_user
    } do
      admin_user_token = Accounts.generate_admin_user_session_token(admin_user)
      session = conn |> put_session(:admin_user_token, admin_user_token) |> get_session()

      {:cont, updated_socket} =
        AdminUserAuth.on_mount(:require_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_scope.admin_user.id == admin_user.id
    end

    test "redirects to login page if there isn't a valid admin_user_token", %{conn: conn} do
      admin_user_token = "invalid_token"
      session = conn |> put_session(:admin_user_token, admin_user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: TesmoinWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        AdminUserAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_scope == nil
    end

    test "redirects to login page if there isn't a admin_user_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: TesmoinWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} =
        AdminUserAuth.on_mount(:require_authenticated, %{}, session, socket)

      assert updated_socket.assigns.current_scope == nil
    end
  end

  describe "on_mount :require_sudo_mode" do
    test "allows admin_users that have authenticated in the last 10 minutes", %{
      conn: conn,
      admin_user: admin_user
    } do
      admin_user_token = Accounts.generate_admin_user_session_token(admin_user)
      session = conn |> put_session(:admin_user_token, admin_user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: TesmoinWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:cont, _updated_socket} =
               AdminUserAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end

    test "redirects when authentication is too old", %{conn: conn, admin_user: admin_user} do
      eleven_minutes_ago = DateTime.utc_now(:second) |> DateTime.add(-11, :minute)
      admin_user = %{admin_user | authenticated_at: eleven_minutes_ago}
      admin_user_token = Accounts.generate_admin_user_session_token(admin_user)
      {admin_user, token_inserted_at} = Accounts.get_admin_user_by_session_token(admin_user_token)
      assert DateTime.compare(token_inserted_at, admin_user.authenticated_at) == :gt
      session = conn |> put_session(:admin_user_token, admin_user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: TesmoinWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      assert {:halt, _updated_socket} =
               AdminUserAuth.on_mount(:require_sudo_mode, %{}, session, socket)
    end
  end

  describe "require_authenticated_admin_user/2" do
    setup %{conn: conn} do
      %{conn: AdminUserAuth.fetch_current_scope_for_admin_user(conn, [])}
    end

    test "redirects if admin_user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> AdminUserAuth.require_authenticated_admin_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/admin_users/log-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> AdminUserAuth.require_authenticated_admin_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :admin_user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> AdminUserAuth.require_authenticated_admin_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :admin_user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> AdminUserAuth.require_authenticated_admin_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :admin_user_return_to)
    end

    test "does not redirect if admin_user is authenticated", %{conn: conn, admin_user: admin_user} do
      conn =
        conn
        |> assign(:current_scope, Scope.for_admin_user(admin_user))
        |> AdminUserAuth.require_authenticated_admin_user([])

      refute conn.halted
      refute conn.status
    end
  end

  describe "disconnect_sessions/1" do
    test "broadcasts disconnect messages for each token" do
      tokens = [%{token: "token1"}, %{token: "token2"}]

      for %{token: token} <- tokens do
        TesmoinWeb.Endpoint.subscribe("admin_users_sessions:#{Base.url_encode64(token)}")
      end

      AdminUserAuth.disconnect_sessions(tokens)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "admin_users_sessions:dG9rZW4x"
      }

      assert_receive %Phoenix.Socket.Broadcast{
        event: "disconnect",
        topic: "admin_users_sessions:dG9rZW4y"
      }
    end
  end
end
