defmodule TesmoinWeb.StoreSessionController do
  use TesmoinWeb, :controller

  alias Tesmoin.Accounts
  alias Tesmoin.Stores

  def create(conn, %{"store_id" => store_id}) do
    current_scope = conn.assigns.current_scope
    parsed_store_id = String.to_integer(store_id)
    store = Stores.get_store!(parsed_store_id)

    case Accounts.set_current_store(current_scope.user, store.id) do
      {:ok, _user} ->
        conn
        |> put_session(:current_store_id, parsed_store_id)
        |> redirect(to: ~p"/")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not update current store. Please try again.")
        |> redirect(to: ~p"/")
    end
  end
end
