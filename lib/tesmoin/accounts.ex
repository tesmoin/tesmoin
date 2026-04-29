defmodule Tesmoin.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Tesmoin.Repo

  alias Tesmoin.Accounts.{AdminUser, AdminUserToken, AdminUserNotifier}

  ## Database getters

  @doc """
  Gets a admin_user by email.

  ## Examples

      iex> get_admin_user_by_email("foo@example.com")
      %AdminUser{}

      iex> get_admin_user_by_email("unknown@example.com")
      nil

  """
  def get_admin_user_by_email(email) when is_binary(email) do
    Repo.get_by(AdminUser, email: email)
  end

  @doc """
  Gets a admin_user by email and password.

  ## Examples

      iex> get_admin_user_by_email_and_password("foo@example.com", "correct_password")
      %AdminUser{}

      iex> get_admin_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_admin_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    admin_user = Repo.get_by(AdminUser, email: email)
    if AdminUser.valid_password?(admin_user, password), do: admin_user
  end

  @doc """
  Gets a single admin_user.

  Raises `Ecto.NoResultsError` if the AdminUser does not exist.

  ## Examples

      iex> get_admin_user!(123)
      %AdminUser{}

      iex> get_admin_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_admin_user!(id), do: Repo.get!(AdminUser, id)

  ## Admin user registration

  @doc """
  Registers a admin_user.

  ## Examples

      iex> register_admin_user(%{field: value})
      {:ok, %AdminUser{}}

      iex> register_admin_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_admin_user(attrs) do
    %AdminUser{}
    |> AdminUser.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the admin_user is in sudo mode.

  The admin_user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(admin_user, minutes \\ -20)

  def sudo_mode?(%AdminUser{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_admin_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the admin_user email.

  See `Tesmoin.Accounts.AdminUser.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_admin_user_email(admin_user)
      %Ecto.Changeset{data: %AdminUser{}}

  """
  def change_admin_user_email(admin_user, attrs \\ %{}, opts \\ []) do
    AdminUser.email_changeset(admin_user, attrs, opts)
  end

  @doc """
  Updates the admin_user email using the given token.

  If the token matches, the admin_user email is updated and the token is deleted.
  """
  def update_admin_user_email(admin_user, token) do
    context = "change:#{admin_user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- AdminUserToken.verify_change_email_token_query(token, context),
           %AdminUserToken{sent_to: email} <- Repo.one(query),
           {:ok, admin_user} <-
             Repo.update(AdminUser.email_changeset(admin_user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(
               from(AdminUserToken, where: [admin_user_id: ^admin_user.id, context: ^context])
             ) do
        {:ok, admin_user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the admin_user password.

  See `Tesmoin.Accounts.AdminUser.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_admin_user_password(admin_user)
      %Ecto.Changeset{data: %AdminUser{}}

  """
  def change_admin_user_password(admin_user, attrs \\ %{}, opts \\ []) do
    AdminUser.password_changeset(admin_user, attrs, opts)
  end

  @doc """
  Updates the admin_user password.

  Returns a tuple with the updated admin_user, as well as a list of expired tokens.

  ## Examples

      iex> update_admin_user_password(admin_user, %{password: ...})
      {:ok, {%AdminUser{}, [...]}}

      iex> update_admin_user_password(admin_user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_admin_user_password(admin_user, attrs) do
    admin_user
    |> AdminUser.password_changeset(attrs)
    |> update_admin_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_admin_user_session_token(admin_user) do
    {token, admin_user_token} = AdminUserToken.build_session_token(admin_user)
    Repo.insert!(admin_user_token)
    token
  end

  @doc """
  Gets the admin_user with the given signed token.

  If the token is valid `{admin_user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_admin_user_by_session_token(token) do
    {:ok, query} = AdminUserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the admin_user with the given magic link token.
  """
  def get_admin_user_by_magic_link_token(token) do
    with {:ok, query} <- AdminUserToken.verify_magic_link_token_query(token),
         {admin_user, _token} <- Repo.one(query) do
      admin_user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the admin_user in by magic link.

  There are three cases to consider:

  1. The admin_user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The admin_user has not confirmed their email and no password is set.
     In this case, the admin_user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The admin_user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_admin_user_by_magic_link(token) do
    {:ok, query} = AdminUserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%AdminUser{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%AdminUser{confirmed_at: nil} = admin_user, _token} ->
        admin_user
        |> AdminUser.confirm_changeset()
        |> update_admin_user_and_delete_all_tokens()

      {admin_user, token} ->
        Repo.delete!(token)
        {:ok, {admin_user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given admin_user.

  ## Examples

      iex> deliver_admin_user_update_email_instructions(admin_user, current_email, &url(~p"/admin_users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_admin_user_update_email_instructions(
        %AdminUser{} = admin_user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, admin_user_token} =
      AdminUserToken.build_email_token(admin_user, "change:#{current_email}")

    Repo.insert!(admin_user_token)

    AdminUserNotifier.deliver_update_email_instructions(
      admin_user,
      update_email_url_fun.(encoded_token)
    )
  end

  @doc """
  Delivers the magic link login instructions to the given admin_user.
  """
  def deliver_login_instructions(%AdminUser{} = admin_user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, admin_user_token} = AdminUserToken.build_email_token(admin_user, "login")
    Repo.insert!(admin_user_token)
    AdminUserNotifier.deliver_login_instructions(admin_user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_admin_user_session_token(token) do
    Repo.delete_all(from(AdminUserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_admin_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, admin_user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(AdminUserToken, admin_user_id: admin_user.id)

        Repo.delete_all(
          from(t in AdminUserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id))
        )

        {:ok, {admin_user, tokens_to_expire}}
      end
    end)
  end
end
