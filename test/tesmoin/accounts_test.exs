defmodule Tesmoin.AccountsTest do
  use Tesmoin.DataCase

  alias Tesmoin.Accounts

  import Tesmoin.AccountsFixtures
  alias Tesmoin.Accounts.{AdminUser, AdminUserToken}

  describe "get_admin_user_by_email/1" do
    test "does not return the admin_user if the email does not exist" do
      refute Accounts.get_admin_user_by_email("unknown@example.com")
    end

    test "returns the admin_user if the email exists" do
      %{id: id} = admin_user = admin_user_fixture()
      assert %AdminUser{id: ^id} = Accounts.get_admin_user_by_email(admin_user.email)
    end
  end

  describe "get_admin_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_admin_user!(-1)
      end
    end

    test "returns the admin_user with the given id" do
      %{id: id} = admin_user = admin_user_fixture()
      assert %AdminUser{id: ^id} = Accounts.get_admin_user!(admin_user.id)
    end
  end

  describe "register_admin_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_admin_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_admin_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_admin_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness" do
      %{email: email} = admin_user_fixture()
      {:error, changeset} = Accounts.register_admin_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the uppercased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_admin_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers admin_users without password" do
      email = unique_admin_user_email()
      {:ok, admin_user} = Accounts.register_admin_user(valid_admin_user_attributes(email: email))
      assert admin_user.email == email
      assert is_nil(admin_user.hashed_password)
      assert is_nil(admin_user.confirmed_at)
      assert is_nil(admin_user.password)
    end
  end

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%AdminUser{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%AdminUser{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%AdminUser{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %AdminUser{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%AdminUser{})
    end
  end

  describe "change_admin_user_email/3" do
    test "returns a admin_user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_admin_user_email(%AdminUser{})
      assert changeset.required == [:email]
    end
  end

  describe "deliver_admin_user_update_email_instructions/3" do
    setup do
      %{admin_user: admin_user_fixture()}
    end

    test "sends token through notification", %{admin_user: admin_user} do
      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_admin_user_update_email_instructions(
            admin_user,
            "current@example.com",
            url
          )
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert admin_user_token = Repo.get_by(AdminUserToken, token: :crypto.hash(:sha256, token))
      assert admin_user_token.admin_user_id == admin_user.id
      assert admin_user_token.sent_to == admin_user.email
      assert admin_user_token.context == "change:current@example.com"
    end
  end

  describe "update_admin_user_email/2" do
    setup do
      admin_user = unconfirmed_admin_user_fixture()
      email = unique_admin_user_email()

      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_admin_user_update_email_instructions(
            %{admin_user | email: email},
            admin_user.email,
            url
          )
        end)

      %{admin_user: admin_user, token: token, email: email}
    end

    test "updates the email with a valid token", %{
      admin_user: admin_user,
      token: token,
      email: email
    } do
      assert {:ok, %{email: ^email}} = Accounts.update_admin_user_email(admin_user, token)
      changed_admin_user = Repo.get!(AdminUser, admin_user.id)
      assert changed_admin_user.email != admin_user.email
      assert changed_admin_user.email == email
      refute Repo.get_by(AdminUserToken, admin_user_id: admin_user.id)
    end

    test "does not update email with invalid token", %{admin_user: admin_user} do
      assert Accounts.update_admin_user_email(admin_user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(AdminUser, admin_user.id).email == admin_user.email
      assert Repo.get_by(AdminUserToken, admin_user_id: admin_user.id)
    end

    test "does not update email if admin_user email changed", %{
      admin_user: admin_user,
      token: token
    } do
      assert Accounts.update_admin_user_email(%{admin_user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(AdminUser, admin_user.id).email == admin_user.email
      assert Repo.get_by(AdminUserToken, admin_user_id: admin_user.id)
    end

    test "does not update email if token expired", %{admin_user: admin_user, token: token} do
      {1, nil} = Repo.update_all(AdminUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_admin_user_email(admin_user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(AdminUser, admin_user.id).email == admin_user.email
      assert Repo.get_by(AdminUserToken, admin_user_id: admin_user.id)
    end
  end

  describe "generate_admin_user_session_token/1" do
    setup do
      %{admin_user: admin_user_fixture()}
    end

    test "generates a token", %{admin_user: admin_user} do
      token = Accounts.generate_admin_user_session_token(admin_user)
      assert admin_user_token = Repo.get_by(AdminUserToken, token: token)
      assert admin_user_token.context == "session"
      assert admin_user_token.authenticated_at != nil

      # Creating the same token for another admin_user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%AdminUserToken{
          token: admin_user_token.token,
          admin_user_id: admin_user_fixture().id,
          context: "session"
        })
      end
    end

    test "duplicates the authenticated_at of given admin_user in new token", %{
      admin_user: admin_user
    } do
      admin_user = %{
        admin_user
        | authenticated_at: DateTime.add(DateTime.utc_now(:second), -3600)
      }

      token = Accounts.generate_admin_user_session_token(admin_user)
      assert admin_user_token = Repo.get_by(AdminUserToken, token: token)
      assert admin_user_token.authenticated_at == admin_user.authenticated_at
      assert DateTime.compare(admin_user_token.inserted_at, admin_user.authenticated_at) == :gt
    end
  end

  describe "get_admin_user_by_session_token/1" do
    setup do
      admin_user = admin_user_fixture()
      token = Accounts.generate_admin_user_session_token(admin_user)
      %{admin_user: admin_user, token: token}
    end

    test "returns admin_user by token", %{admin_user: admin_user, token: token} do
      assert {session_admin_user, token_inserted_at} =
               Accounts.get_admin_user_by_session_token(token)

      assert session_admin_user.id == admin_user.id
      assert session_admin_user.authenticated_at != nil
      assert token_inserted_at != nil
    end

    test "does not return admin_user for invalid token" do
      refute Accounts.get_admin_user_by_session_token("oops")
    end

    test "does not return admin_user for expired token", %{token: token} do
      dt = ~N[2020-01-01 00:00:00]
      {1, nil} = Repo.update_all(AdminUserToken, set: [inserted_at: dt, authenticated_at: dt])
      refute Accounts.get_admin_user_by_session_token(token)
    end
  end

  describe "get_admin_user_by_magic_link_token/1" do
    setup do
      admin_user = admin_user_fixture()
      {encoded_token, _hashed_token} = generate_admin_user_magic_link_token(admin_user)
      %{admin_user: admin_user, token: encoded_token}
    end

    test "returns admin_user by token", %{admin_user: admin_user, token: token} do
      assert session_admin_user = Accounts.get_admin_user_by_magic_link_token(token)
      assert session_admin_user.id == admin_user.id
    end

    test "does not return admin_user for invalid token" do
      refute Accounts.get_admin_user_by_magic_link_token("oops")
    end

    test "does not return admin_user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(AdminUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_admin_user_by_magic_link_token(token)
    end
  end

  describe "login_admin_user_by_magic_link/1" do
    test "confirms admin_user and expires tokens" do
      admin_user = unconfirmed_admin_user_fixture()
      refute admin_user.confirmed_at
      {encoded_token, hashed_token} = generate_admin_user_magic_link_token(admin_user)

      assert {:ok, {admin_user, [%{token: ^hashed_token}]}} =
               Accounts.login_admin_user_by_magic_link(encoded_token)

      assert admin_user.confirmed_at
    end

    test "returns admin_user and (deleted) token for confirmed admin_user" do
      admin_user = admin_user_fixture()
      assert admin_user.confirmed_at
      {encoded_token, _hashed_token} = generate_admin_user_magic_link_token(admin_user)
      assert {:ok, {^admin_user, []}} = Accounts.login_admin_user_by_magic_link(encoded_token)
      # one time use only
      assert {:error, :not_found} = Accounts.login_admin_user_by_magic_link(encoded_token)
    end

    test "raises when unconfirmed admin_user has password set" do
      admin_user = unconfirmed_admin_user_fixture()

      {1, nil} =
        Repo.update_all(from(u in AdminUser, where: u.id == ^admin_user.id),
          set: [hashed_password: "hashed"]
        )

      {encoded_token, _hashed_token} = generate_admin_user_magic_link_token(admin_user)

      assert_raise RuntimeError, ~r/magic link log in is not allowed/, fn ->
        Accounts.login_admin_user_by_magic_link(encoded_token)
      end
    end
  end

  describe "delete_admin_user_session_token/1" do
    test "deletes the token" do
      admin_user = admin_user_fixture()
      token = Accounts.generate_admin_user_session_token(admin_user)
      assert Accounts.delete_admin_user_session_token(token) == :ok
      refute Accounts.get_admin_user_by_session_token(token)
    end
  end

  describe "deliver_login_instructions/2" do
    setup do
      %{admin_user: unconfirmed_admin_user_fixture()}
    end

    test "sends token through notification", %{admin_user: admin_user} do
      token =
        extract_admin_user_token(fn url ->
          Accounts.deliver_login_instructions(admin_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert admin_user_token = Repo.get_by(AdminUserToken, token: :crypto.hash(:sha256, token))
      assert admin_user_token.admin_user_id == admin_user.id
      assert admin_user_token.sent_to == admin_user.email
      assert admin_user_token.context == "login"
    end
  end

  describe "inspect/2 for the AdminUser module" do
    test "does not include password" do
      refute inspect(%AdminUser{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
