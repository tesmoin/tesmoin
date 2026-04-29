defmodule TesmoinWeb.PageController do
  use TesmoinWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
