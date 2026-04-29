defmodule TesmoinWeb.Plugs.RealIP do
  @moduledoc """
  Extracts the real client IP from the `X-Forwarded-For` or `X-Real-IP`
  request headers, but only when the connection arrives from a trusted proxy.

  This prevents attackers from spoofing their IP by sending a crafted
  `X-Forwarded-For` header to Tesmoin directly.

  ## Configuration

  Set `TRUSTED_PROXIES` in the environment as a comma-separated list of IP
  addresses that are allowed to set forwarding headers. Typically this is the
  address of your reverse proxy (Nginx, Traefik, etc.).

  For Docker deployments where the proxy and app share a bridge network, you
  will usually need to add the gateway IP of the Docker bridge (e.g. 172.17.0.1)
  and/or the loopback address (127.0.0.1).

  Example:
      TRUSTED_PROXIES=127.0.0.1,10.0.0.1,172.17.0.1

  If `TRUSTED_PROXIES` is not set (or empty), the plug is a no-op and
  `conn.remote_ip` is used as-is (safe default for direct connections).
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    trusted = Application.get_env(:tesmoin, :trusted_proxies, [])

    if conn.remote_ip in trusted do
      case extract_real_ip(conn) do
        nil -> conn
        ip -> %{conn | remote_ip: ip}
      end
    else
      conn
    end
  end

  defp extract_real_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        # X-Forwarded-For: client, proxy1, proxy2
        # The leftmost is the original client IP.
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()
        |> parse_ip()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [ip | _] -> parse_ip(String.trim(ip))
          [] -> nil
        end
    end
  end

  defp parse_ip(ip_string) do
    case :inet.parse_address(String.to_charlist(ip_string)) do
      {:ok, ip} -> ip
      _ -> nil
    end
  end
end
