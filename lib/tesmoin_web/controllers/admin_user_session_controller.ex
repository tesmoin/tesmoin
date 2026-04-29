defmodule TesmoinWeb.AdminUserSessionController do
  use TesmoinWeb, :controller

  require Logger

  alias Tesmoin.Accounts
  alias Tesmoin.RateLimiter
  alias TesmoinWeb.AdminUserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "Admin user confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"admin_user" => %{"token" => token} = admin_user_params}, info) do
    client_ip = conn.remote_ip

    case RateLimiter.check_token_redemption(client_ip) do
      :rate_limited ->
        conn
        |> put_flash(:error, "Too many requests. Please wait a minute before trying again.")
        |> redirect(to: ~p"/admin_users/log-in")

      :ok ->
        case Accounts.login_admin_user_by_magic_link(token) do
          {:ok, {admin_user, tokens_to_disconnect}} ->
            Logger.info("Magic link login succeeded", admin_user_id: admin_user.id)
            AdminUserAuth.disconnect_sessions(tokens_to_disconnect)

            conn
            |> put_flash(:info, info)
            |> AdminUserAuth.log_in_admin_user(admin_user, admin_user_params)

          _ ->
            Logger.warning("Magic link token invalid or expired",
              client_ip: inspect(client_ip)
            )

            conn
            |> put_flash(:error, "The link is invalid or it has expired.")
            |> redirect(to: ~p"/admin_users/log-in")
        end
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
