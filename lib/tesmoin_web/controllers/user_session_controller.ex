defmodule TesmoinWeb.UserSessionController do
  use TesmoinWeb, :controller

  require Logger

  alias Tesmoin.Accounts
  alias Tesmoin.RateLimiter
  alias TesmoinWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    do_create(conn, params)
  end

  def create(conn, params) do
    do_create(conn, params)
  end

  # magic link login
  defp do_create(conn, %{"user" => %{"token" => token} = user_params}) do
    client_ip = conn.remote_ip

    case RateLimiter.check_token_redemption(client_ip) do
      :rate_limited ->
        conn
        |> put_flash(:error, "Too many requests. Please wait a minute before trying again.")
        |> redirect(to: ~p"/users/log-in")

      :ok ->
        case Accounts.login_user_by_magic_link(token) do
          {:ok, {user, tokens_to_disconnect}} ->
            Logger.info("Magic link login succeeded", user_id: user.id)
            UserAuth.disconnect_sessions(tokens_to_disconnect)

            conn
            |> UserAuth.log_in_user(user, user_params)

          _ ->
            Logger.warning("Magic link token invalid or expired",
              client_ip: inspect(client_ip)
            )

            conn
            |> put_flash(:error, "The link is invalid or it has expired.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  defp do_create(conn, _params) do
    conn
    |> put_flash(:error, "The link is invalid or it has expired.")
    |> redirect(to: ~p"/users/log-in")
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
