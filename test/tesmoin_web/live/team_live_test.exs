defmodule TesmoinWeb.TeamLiveTest do
  use TesmoinWeb.ConnCase, async: true

  alias Tesmoin.Repo
  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Stores.{Store, StoreMembership}
  import Phoenix.LiveViewTest
  import Tesmoin.AccountsFixtures

  describe "invite permissions" do
    test "admin sees invite button", %{conn: conn} do
      admin_user = admin_user_fixture(%{role: "admin"})

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/team")

      assert has_element?(lv, "button[phx-click='show-invite-form']")
    end

    test "editor does not see invite button", %{conn: conn} do
      editor = admin_user_fixture(%{role: "editor"})
      _admin = admin_user_fixture(%{role: "admin"})

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(editor)
        |> live(~p"/team")

      refute has_element?(lv, "button[phx-click='show-invite-form']")
    end

    test "editor cannot trigger invite via event", %{conn: conn} do
      editor = admin_user_fixture(%{role: "editor"})
      _admin = admin_user_fixture(%{role: "admin"})

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(editor)
        |> live(~p"/team")

      # send the event directly, simulating a crafted WebSocket message
      render_click(lv, "show-invite-form")

      # invite form must not appear
      refute has_element?(lv, "#invite-form")
    end
  end

  describe "team role management" do
    test "admin can change role for a non-admin member", %{conn: conn} do
      admin_user = admin_user_fixture(%{role: "admin"})
      member = admin_user_fixture(%{role: "moderator"})
      store = store_fixture()
      _admin_membership = membership_fixture(admin_user, store)
      _member_membership = membership_fixture(member, store)

      {:ok, lv, _html} =
        conn
        |> log_in_admin_user(admin_user)
        |> live(~p"/team")

      lv
      |> form("#member-role-form-#{member.id}", %{member_id: member.id, role: "editor"})
      |> render_submit()

      updated_member = Repo.get!(AdminUser, member.id)
      assert updated_member.role == "editor"
    end

    test "admin cannot edit another admin role", %{conn: conn} do
      admin_user = admin_user_fixture(%{role: "admin"})
      other_admin = admin_user_fixture(%{role: "admin"})
      store = store_fixture()
      _admin_membership_1 = membership_fixture(admin_user, store)
      _admin_membership_2 = membership_fixture(other_admin, store)

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

  defp membership_fixture(admin_user, store) do
    %StoreMembership{}
    |> StoreMembership.changeset(%{admin_user_id: admin_user.id, store_id: store.id})
    |> Repo.insert!()
  end
end
