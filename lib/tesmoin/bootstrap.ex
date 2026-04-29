defmodule Tesmoin.Bootstrap do
  @moduledoc """
  Handles first-boot setup for the Tesmoin node.

  On application start, this module checks whether any admin user exists.
  If none exists, it reads TESMOIN_ADMIN_EMAIL and TESMOIN_ADMIN_PASSWORD
  from the environment and creates the initial admin account.

  In Docker deployments these variables are set via the environment.
  In local development they come from the .env file loaded at runtime.
  """

  require Logger

  alias Tesmoin.Accounts

  @doc """
  Seeds the admin user from environment variables if no admin user exists yet.
  Safe to call on every boot — it is a no-op when an admin already exists.
  """
  def seed_admin_user do
    email = System.get_env("TESMOIN_ADMIN_EMAIL")
    password = System.get_env("TESMOIN_ADMIN_PASSWORD")

    cond do
      is_nil(email) or is_nil(password) ->
        Logger.warning(
          "Bootstrap: TESMOIN_ADMIN_EMAIL or TESMOIN_ADMIN_PASSWORD not set. " <>
            "No admin user will be seeded automatically."
        )

      Accounts.get_admin_user_by_email(email) ->
        :ok

      true ->
        case Accounts.register_admin_user(%{email: email, password: password}) do
          {:ok, _user} ->
            Logger.info("Bootstrap: Admin user #{email} created successfully.")

          {:error, changeset} ->
            Logger.error("Bootstrap: Failed to create admin user: #{inspect(changeset.errors)}")
        end
    end
  end
end
