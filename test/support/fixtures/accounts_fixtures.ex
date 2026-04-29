defmodule Tesmoin.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Tesmoin.Accounts` context.
  """

  import Ecto.Query

  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.Scope

  def unique_admin_user_email, do: "admin_user#{System.unique_integer()}@example.com"
  def valid_admin_user_password, do: "hello world!"

  def valid_admin_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_admin_user_email()
    })
  end

  def unconfirmed_admin_user_fixture(attrs \\ %{}) do
    {:ok, admin_user} =
      attrs
      |> valid_admin_user_attributes()
      |> Accounts.register_admin_user()

    admin_user
  end

  def admin_user_fixture(attrs \\ %{}) do
    admin_user = unconfirmed_admin_user_fixture(attrs)

    token =
      extract_admin_user_token(fn url ->
        Accounts.deliver_login_instructions(admin_user, url)
      end)

    {:ok, {admin_user, _expired_tokens}} =
      Accounts.login_admin_user_by_magic_link(token)

    admin_user
  end

  def admin_user_scope_fixture do
    admin_user = admin_user_fixture()
    admin_user_scope_fixture(admin_user)
  end

  def admin_user_scope_fixture(admin_user) do
    Scope.for_admin_user(admin_user)
  end

  def extract_admin_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    Tesmoin.Repo.update_all(
      from(t in Accounts.AdminUserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_admin_user_magic_link_token(admin_user) do
    {encoded_token, admin_user_token} =
      Accounts.AdminUserToken.build_email_token(admin_user, "login")

    Tesmoin.Repo.insert!(admin_user_token)
    {encoded_token, admin_user_token.token}
  end

  def offset_admin_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    Tesmoin.Repo.update_all(
      from(ut in Accounts.AdminUserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
