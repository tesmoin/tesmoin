defmodule TesmoinWeb.StoreSessionControllerTest do
  use TesmoinWeb.ConnCase, async: true

  import Tesmoin.AccountsFixtures

  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.Scope
  alias Tesmoin.Stores

  describe "POST /stores/switch" do
    test "persists selected store in session and admin user", %{conn: conn} do
      user = user_fixture()
      scope = Scope.for_user(user)

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
        |> log_in_user(user)
        |> post(~p"/stores/switch", %{"store_id" => Integer.to_string(store2.id)})

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :current_store_id) == store2.id
      assert Accounts.get_user!(user.id).current_store_id == store2.id
      assert store1.id != store2.id
    end
  end
end
