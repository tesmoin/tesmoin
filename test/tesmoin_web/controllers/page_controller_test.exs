defmodule TesmoinWeb.PageControllerTest do
  use TesmoinWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/admin_users/log-in"
  end
end
