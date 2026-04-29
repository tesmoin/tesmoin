defmodule TesmoinWeb.StoreSessionController do
  use TesmoinWeb, :controller

  alias Tesmoin.Stores

  def create(conn, %{"store_id" => store_id}) do
    current_scope = conn.assigns.current_scope
    parsed_store_id = String.to_integer(store_id)

    if member_store?(current_scope.admin_user.id, parsed_store_id) do
      conn
      |> put_session(:current_store_id, parsed_store_id)
      |> redirect(to: ~p"/")
    else
      conn
      |> put_flash(:error, "You do not have access to that store.")
      |> redirect(to: ~p"/")
    end
  end

  defp member_store?(admin_user_id, store_id) do
    admin_user_id
    |> Stores.list_stores_for_admin_user()
    |> Enum.any?(&(&1.id == store_id))
  end
end
