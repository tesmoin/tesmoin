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
  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Repo

  @doc """
  Seeds the admin user from environment variables if no admin user exists yet.
  Safe to call on every boot — it is a no-op when an admin already exists.
  """
  def seed_admin_user do
    email = System.get_env("TESMOIN_ADMIN_EMAIL")
    password = System.get_env("TESMOIN_ADMIN_PASSWORD")

    cond do
      is_nil(email) ->
        Logger.warning(
          "Bootstrap: TESMOIN_ADMIN_EMAIL is not set. " <>
            "No admin user will be seeded automatically."
        )

      admin_user = Accounts.get_admin_user_by_email(email) ->
        maybe_set_bootstrap_password(admin_user, password)
        maybe_confirm_admin_user(admin_user)

      true ->
        with {:ok, admin_user} <- Accounts.register_admin_user(%{email: email}) do
          maybe_set_bootstrap_password(admin_user, password)
          maybe_confirm_admin_user(admin_user)

          Logger.info("Bootstrap: Admin user #{email} created successfully.")
        else
          {:error, changeset} ->
            Logger.error("Bootstrap: Failed to create admin user: #{inspect(changeset.errors)}")
        end
    end
  end

  defp maybe_set_bootstrap_password(_admin_user, nil) do
    Logger.warning(
      "Bootstrap: TESMOIN_ADMIN_PASSWORD is not set. " <>
        "Admin user can still log in with a magic link."
    )
  end

  defp maybe_set_bootstrap_password(%{hashed_password: nil} = admin_user, password) do
    case Accounts.update_admin_user_password(admin_user, %{password: password}) do
      {:ok, _result} ->
        Logger.info(
          "Bootstrap: Admin user #{admin_user.email} password was initialized from env."
        )

      {:error, changeset} ->
        Logger.error(
          "Bootstrap: Failed to initialize admin password: #{inspect(changeset.errors)}"
        )
    end
  end

  defp maybe_set_bootstrap_password(_admin_user, _password), do: :ok

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
