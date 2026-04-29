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

  defp create(conn, _params, _info) do
    conn
    |> put_flash(:error, "The link is invalid or it has expired.")
    |> redirect(to: ~p"/admin_users/log-in")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AdminUserAuth.log_out_admin_user()
  end
end
