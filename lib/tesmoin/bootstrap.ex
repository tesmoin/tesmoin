defmodule Tesmoin.Bootstrap do
  @moduledoc """
  Handles first-boot setup for the Tesmoin node.

  On application start, this module checks whether any admin user exists.
  If none exists, it reads TESMOIN_ADMIN_EMAIL from the environment and
  creates a confirmed admin account. The admin then logs in via magic link.

  In Docker deployments the variable is set via the environment.
  In local development it comes from the .env file loaded at runtime.
  """

  require Logger

  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Repo

  @doc """
  Seeds the admin user from environment variables if no admin user exists yet.
  Safe to call on every boot — it is a no-op when an admin already exists.
  """
  def seed_admin_user do
    email = System.get_env("TESMOIN_ADMIN_EMAIL")

    cond do
      is_nil(email) ->
        Logger.warning(
          "Bootstrap: TESMOIN_ADMIN_EMAIL is not set. " <>
            "No admin user will be seeded automatically. " <>
            "Use the /setup wizard to create the first admin account."
        )

      admin_user = Accounts.get_admin_user_by_email(email) ->
        maybe_confirm_admin_user(admin_user)

      true ->
        with {:ok, admin_user} <- Accounts.register_admin_user(%{email: email}) do
          maybe_confirm_admin_user(admin_user)
          Logger.info("Bootstrap: Admin user #{email} created. Log in via magic link.")
        else
          {:error, changeset} ->
            Logger.error("Bootstrap: Failed to create admin user: #{inspect(changeset.errors)}")
        end
    end
  end

  defp maybe_confirm_admin_user(%AdminUser{confirmed_at: nil} = admin_user) do
    case admin_user |> AdminUser.confirm_changeset() |> Repo.update() do
      {:ok, _updated_admin_user} ->
        Logger.info("Bootstrap: Admin user #{admin_user.email} was confirmed.")

      {:error, changeset} ->
        Logger.error("Bootstrap: Failed to confirm admin user: #{inspect(changeset.errors)}")
    end
  end

  defp maybe_confirm_admin_user(_admin_user), do: :ok
end
