defmodule Tesmoin.Repo do
  use Ecto.Repo,
    otp_app: :tesmoin,
    adapter: Ecto.Adapters.Postgres
end
