defmodule TesmoinWeb.AdminUserSessionController do
  use TesmoinWeb, :controller

  alias Tesmoin.Accounts
  alias TesmoinWeb.AdminUserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Admin user confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"admin_user" => %{"token" => token} = admin_user_params}, info) do
    case Accounts.login_admin_user_by_magic_link(token) do
      {:ok, {admin_user, tokens_to_disconnect}} ->
        AdminUserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> AdminUserAuth.log_in_admin_user(admin_user, admin_user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/admin_users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"admin_user" => admin_user_params}, info) do
    %{"email" => email, "password" => password} = admin_user_params

    if admin_user = Accounts.get_admin_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> AdminUserAuth.log_in_admin_user(admin_user, admin_user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/admin_users/log-in")
    end
  end

  def update_password(conn, %{"admin_user" => admin_user_params} = params) do
    admin_user = conn.assigns.current_scope.admin_user
    true = Accounts.sudo_mode?(admin_user)

    {:ok, {_admin_user, expired_tokens}} =
      Accounts.update_admin_user_password(admin_user, admin_user_params)

    # disconnect all existing LiveViews with old sessions
    AdminUserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:admin_user_return_to, ~p"/admin_users/settings")
    |> create(params, "Password updated successfully!")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AdminUserAuth.log_out_admin_user()
  end
end
