defmodule Tesmoin.RateLimiter do
  @moduledoc """
  Rate limiting for auth endpoints using Hammer (ETS backend).

  Limits are applied per client IP address. In tests, rate limiting is
  disabled entirely via `config :tesmoin, :rate_limiter_enabled, false`.

  Buckets:
  - magic_link_request: 5 requests per 60 seconds per IP
  - token_redemption:   10 attempts per 60 seconds per IP
  """

  require Logger

  # 5 magic link requests per minute per IP
  @magic_link_limit 5
  @magic_link_scale_ms 60_000

  # 10 token redemption attempts per minute per IP (tokens are single-use, this
  # mainly protects against enumeration of token URLs)
  @token_redemption_limit 10
  @token_redemption_scale_ms 60_000

  @doc """
  Checks whether the given IP is allowed to request a magic link.
  Returns `:ok` or `:rate_limited`.
  """
  def check_magic_link_request(ip) do
    check("magic_link_request:#{format_ip(ip)}", @magic_link_scale_ms, @magic_link_limit)
  end

  @doc """
  Checks whether the given IP is allowed to attempt a token redemption.
  Returns `:ok` or `:rate_limited`.
  """
  def check_token_redemption(ip) do
    check(
      "token_redemption:#{format_ip(ip)}",
      @token_redemption_scale_ms,
      @token_redemption_limit
    )
  end

  defp check(key, scale_ms, limit) do
    if Application.get_env(:tesmoin, :rate_limiter_enabled, true) do
      case Hammer.check_rate(key, scale_ms, limit) do
        {:allow, _count} ->
          :ok

        {:deny, _limit} ->
          Logger.warning("Rate limit exceeded", bucket: key)
          :rate_limited
      end
    else
      :ok
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_ip({a, b, c, d, e, f, g, h}), do: "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
  defp format_ip(other), do: inspect(other)
end
