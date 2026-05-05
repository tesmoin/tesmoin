defmodule TesmoinWeb.StoreSessionControllerTest do
  use TesmoinWeb.ConnCase, async: true

  import Tesmoin.AccountsFixtures

  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.Scope
  alias Tesmoin.Stores

  describe "POST /stores/switch" do
    test "persists selected store in session and admin user", %{conn: conn} do
      admin_user = admin_user_fixture()
      scope = Scope.for_admin_user(admin_user)

      {:ok, store1} =
        Stores.create_store(scope, %{
          "name" => "Alpha",
          "slug" => "alpha-#{System.unique_integer([:positive])}",
          "status" => "live"
        })

      {:ok, store2} =
        Stores.create_store(scope, %{
          "name" => "Beta",
          "slug" => "beta-#{System.unique_integer([:positive])}",
          "status" => "live"
        })

      conn =
        conn
        |> log_in_admin_user(admin_user)
        |> post(~p"/stores/switch", %{"store_id" => Integer.to_string(store2.id)})

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_store_id) == store2.id
      assert Accounts.get_admin_user!(admin_user.id).current_store_id == store2.id
      assert store1.id != store2.id
    end

    test "rejects switching to a store the user cannot access", %{conn: conn} do
      admin_user = admin_user_fixture()
      other_admin = admin_user_fixture()
      other_scope = Scope.for_admin_user(other_admin)

      {:ok, other_store} =
        Stores.create_store(other_scope, %{
          "name" => "Other",
          "slug" => "other-#{System.unique_integer([:positive])}",
          "status" => "live"
        })

      conn =
        conn
        |> log_in_admin_user(admin_user)
        |> post(~p"/stores/switch", %{"store_id" => Integer.to_string(other_store.id)})

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You do not have access to that store."

      assert get_session(conn, :current_store_id) == nil
      assert Accounts.get_admin_user!(admin_user.id).current_store_id == nil
    end
  end
end
