defmodule TesmoinWeb.AdminUserAuth do
  use TesmoinWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.Scope

  # Make the remember me cookie valid for 14 days. This should match
  # the session validity setting in AdminUserToken.
  @max_cookie_age_in_days 14
  @remember_me_cookie "_tesmoin_web_admin_user_remember_me"
  @remember_me_options [
    sign: true,
    max_age: @max_cookie_age_in_days * 24 * 60 * 60,
    same_site: "Lax",
    http_only: true,
    secure: Application.compile_env(:tesmoin, :session_secure, false)
  ]

  # How old the session token should be before a new one is issued. When a request is made
  # with a session token older than this value, then a new session token will be created
  # and the session and remember-me cookies (if set) will be updated with the new token.
  # Lowering this value will result in more tokens being created by active users. Increasing
  # it will result in less time before a session token expires for a user to get issued a new
  # token. This can be set to a value greater than `@max_cookie_age_in_days` to disable
  # the reissuing of tokens completely.
  @session_reissue_age_in_days 7

  @doc """
  Logs the admin_user in.

  Redirects to the session's `:admin_user_return_to` path
  or falls back to the `signed_in_path/1`.
  """
  def log_in_admin_user(conn, admin_user, params \\ %{}) do
    admin_user_return_to = get_session(conn, :admin_user_return_to)

    conn
    |> create_or_extend_session(admin_user, params)
    |> redirect(to: admin_user_return_to || signed_in_path(conn))
  end

  @doc """
  Logs the admin_user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_admin_user(conn) do
    admin_user_token = get_session(conn, :admin_user_token)
    admin_user_token && Accounts.delete_admin_user_session_token(admin_user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      TesmoinWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session(nil)
    |> delete_resp_cookie(@remember_me_cookie, @remember_me_options)
    |> redirect(to: ~p"/")
  end

  @doc """
  Authenticates the admin_user by looking into the session and remember me token.

  Will reissue the session token if it is older than the configured age.
  """
  def fetch_current_scope_for_admin_user(conn, _opts) do
    with {token, conn} <- ensure_admin_user_token(conn),
         {admin_user, token_inserted_at} <- Accounts.get_admin_user_by_session_token(token) do
      conn
      |> assign(:current_scope, Scope.for_admin_user(admin_user))
      |> maybe_reissue_admin_user_session_token(admin_user, token_inserted_at)
    else
      nil -> assign(conn, :current_scope, Scope.for_admin_user(nil))
    end
  end

  defp ensure_admin_user_token(conn) do
    if token = get_session(conn, :admin_user_token) do
      {token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if token = conn.cookies[@remember_me_cookie] do
        {token, conn |> put_token_in_session(token) |> put_session(:admin_user_remember_me, true)}
      else
        nil
      end
    end
  end

  # Reissue the session token if it is older than the configured reissue age.
  defp maybe_reissue_admin_user_session_token(conn, admin_user, token_inserted_at) do
    token_age = DateTime.diff(DateTime.utc_now(:second), token_inserted_at, :day)

    if token_age >= @session_reissue_age_in_days do
      create_or_extend_session(conn, admin_user, %{})
    else
      conn
    end
  end

  # This function is the one responsible for creating session tokens
  # and storing them safely in the session and cookies. It may be called
  # either when logging in, during sudo mode, or to renew a session which
  # will soon expire.
  #
  # When the session is created, rather than extended, the renew_session
  # function will clear the session to avoid fixation attacks. See the
  # renew_session function to customize this behaviour.
  defp create_or_extend_session(conn, admin_user, params) do
    token = Accounts.generate_admin_user_session_token(admin_user)
    remember_me = get_session(conn, :admin_user_remember_me)

    conn
    |> renew_session(admin_user)
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params, remember_me)
  end

  # Do not renew session if the admin_user is already logged in
  # to prevent CSRF errors or data being lost in tabs that are still open
  defp renew_session(conn, admin_user)
       when conn.assigns.current_scope.admin_user.id == admin_user.id do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn, _admin_user) do
  #       delete_csrf_token()
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn, _admin_user) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}, _),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, token, _params, true),
    do: write_remember_me_cookie(conn, token)

  defp maybe_write_remember_me_cookie(conn, _token, _params, _), do: conn

  defp write_remember_me_cookie(conn, token) do
    conn
    |> put_session(:admin_user_remember_me, true)
    |> put_resp_cookie(@remember_me_cookie, token, @remember_me_options)
  end

  defp put_token_in_session(conn, token) do
    conn
    |> put_session(:admin_user_token, token)
    |> put_session(:live_socket_id, admin_user_session_topic(token))
  end

  @doc """
  Disconnects existing sockets for the given tokens.
  """
  def disconnect_sessions(tokens) do
    Enum.each(tokens, fn %{token: token} ->
      TesmoinWeb.Endpoint.broadcast(admin_user_session_topic(token), "disconnect", %{})
    end)
  end

  defp admin_user_session_topic(token), do: "admin_users_sessions:#{Base.url_encode64(token)}"

  @doc """
  Handles mounting and authenticating the current_scope in LiveViews.

  ## `on_mount` arguments

    * `:mount_current_scope` - Assigns current_scope
      to socket assigns based on admin_user_token, or nil if
      there's no admin_user_token or no matching admin_user.

    * `:require_authenticated` - Authenticates the admin_user from the session,
      and assigns the current_scope to socket assigns based
      on admin_user_token.
      Redirects to login page if there's no logged admin_user.

  ## Examples

  Use the `on_mount` lifecycle macro in LiveViews to mount or authenticate
  the `current_scope`:

      defmodule TesmoinWeb.PageLive do
        use TesmoinWeb, :live_view

        on_mount {TesmoinWeb.AdminUserAuth, :mount_current_scope}
        ...
      end

  Or use the `live_session` of your router to invoke the on_mount callback:

      live_session :authenticated, on_mount: [{TesmoinWeb.AdminUserAuth, :require_authenticated}] do
        live "/profile", ProfileLive, :index
      end
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:redirect_if_admin_user_is_authenticated, params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.admin_user &&
         params["reauth"] != "true" do
      socket =
        Phoenix.LiveView.redirect(socket,
          to: signed_in_path_for_scope(socket.assigns.current_scope)
        )

      {:halt, socket}
    else
      {:cont, socket}
    end
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.admin_user do
      {:cont, mount_store_context(socket, session)}
    else
      socket =
        socket
        |> Phoenix.LiveView.redirect(to: ~p"/admin_users/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:require_sudo_mode, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if Accounts.sudo_mode?(socket.assigns.current_scope.admin_user, -10) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must re-authenticate to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/admin_users/log-in?reauth=true")

      {:halt, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign_new(socket, :current_scope, fn ->
      {admin_user, _} =
        if admin_user_token = session["admin_user_token"] do
          Accounts.get_admin_user_by_session_token(admin_user_token)
        end || {nil, nil}

      Scope.for_admin_user(admin_user)
    end)
  end

  defp mount_store_context(socket, session) do
    admin_user_id = socket.assigns.current_scope.admin_user.id

    socket
    |> Phoenix.Component.assign_new(:stores, fn ->
      Tesmoin.Stores.list_stores_for_admin_user(admin_user_id)
    end)
    |> Phoenix.Component.assign_new(:current_store, fn %{stores: stores} ->
      current_store_id = session["current_store_id"]

      if current_store_id do
        Enum.find(stores, List.first(stores), &(&1.id == current_store_id))
      else
        List.first(stores)
      end
    end)
  end

  @doc "Returns the path to redirect to after log in."
  # the admin_user was already logged in, redirect to settings
  def signed_in_path(%Plug.Conn{
        assigns: %{current_scope: %Scope{admin_user: %Accounts.AdminUser{}}}
      }) do
    ~p"/admin_users/settings"
  end

  def signed_in_path(_), do: ~p"/"

  defp signed_in_path_for_scope(%Scope{admin_user: %Accounts.AdminUser{}}),
    do: ~p"/admin_users/settings"

  defp signed_in_path_for_scope(_), do: ~p"/"

  @doc """
  Plug for routes that require the admin_user to be authenticated.
  """
  def require_authenticated_admin_user(conn, _opts) do
    if conn.assigns.current_scope && conn.assigns.current_scope.admin_user do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> redirect(to: ~p"/admin_users/log-in")
      |> halt()
    end
  end

  @doc """
  Redirects away from auth-entry pages when an admin user is already authenticated.
  """
  def redirect_if_admin_user_is_authenticated(conn, _opts) do
    conn = fetch_query_params(conn)

    if conn.assigns.current_scope && conn.assigns.current_scope.admin_user &&
         conn.params["reauth"] != "true" do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :admin_user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  @doc """
  Redirects to /setup when no admin user exists yet.
  Exempt paths: /setup, /admin_users/log-in*, /admin_users/log-out, /dev/mailbox*, /dev/dashboard*.
  """
  def redirect_to_setup_if_needed(conn, _opts) do
    if setup_path_exempt?(conn.request_path) or Accounts.admin_user_exists?() do
      conn
    else
      conn |> redirect(to: ~p"/setup") |> halt()
    end
  end

  defp setup_path_exempt?(path) do
    path == "/setup" or
      String.starts_with?(path, "/admin_users/log-in") or
      path == "/admin_users/log-out" or
      String.starts_with?(path, "/dev/mailbox") or
      String.starts_with?(path, "/dev/dashboard")
  end
end
