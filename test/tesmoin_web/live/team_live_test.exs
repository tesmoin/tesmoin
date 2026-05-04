defmodule TesmoinWeb.TeamLiveTest do
  use TesmoinWeb.ConnCase, async: true

  alias Tesmoin.Repo
  import Ecto.Query
  alias Tesmoin.Stores.{Store, StoreMembership}
  import Phoenix.LiveViewTest
  import Tesmoin.AccountsFixtures

  describe "team role management" do
    test "admin can change role for a non-admin member", %{conn: conn} do
      admin_user = admin_user_fixture()
      member = admin_user_fixture()
      store = store_fixture()
      _admin_membership = membership_fixture(admin_user, store, "admin")
      _member_membership = membership_fixture(member, store, "moderator")

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/team")

      lv
      |> form("#member-role-form-#{member.id}", %{member_id: member.id, role: "editor"})
      |> render_submit()

      roles =
        StoreMembership
        |> where([m], m.admin_user_id == ^member.id)
        |> select([m], m.role)
        |> Repo.all()

      assert roles != []
      assert Enum.all?(roles, &(&1 == "editor"))
    end

    test "admin cannot edit another admin role", %{conn: conn} do
      admin_user = admin_user_fixture()
      other_admin = admin_user_fixture()
      store = store_fixture()
      _admin_membership_1 = membership_fixture(admin_user, store, "admin")
      _admin_membership_2 = membership_fixture(other_admin, store, "admin")

      {:ok, _lv, html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/team")

      refute html =~ "member-role-form-#{other_admin.id}"
      assert html =~ "Admin"
    end
  end

  defp store_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      name: "Store #{unique}",
      slug: "store-#{unique}",
      status: "live"
    }

    %Store{}
    |> Store.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp membership_fixture(admin_user, store, role) do
    %StoreMembership{}
    |> StoreMembership.changeset(%{admin_user_id: admin_user.id, store_id: store.id, role: role})
    |> Repo.insert!()
  end
end
