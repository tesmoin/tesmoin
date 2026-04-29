defmodule Tesmoin.Stores do
  @moduledoc """
  Context for managing stores.

  A store represents a single ecommerce storefront.
  All business data (reviews, orders, invitations, etc.)
  is siloed by store.
  """

  import Ecto.Query

  alias Tesmoin.Repo
  alias Tesmoin.Accounts.Scope
  alias Tesmoin.Stores.Store
  alias Tesmoin.Stores.StoreMembership

  @doc "Returns all stores."
  def list_stores do
    Repo.all(from s in Store, order_by: [asc: s.inserted_at])
  end

  @doc "Returns stores the admin user is a member of."
  def list_stores_for_admin_user(admin_user_id) when is_integer(admin_user_id) do
    Store
    |> join(:inner, [s], m in StoreMembership, on: m.store_id == s.id)
    |> where([_s, m], m.admin_user_id == ^admin_user_id)
    |> order_by([s, _m], asc: s.inserted_at)
    |> distinct(true)
    |> Repo.all()
  end

  @doc "Returns the total number of stores on this node."
  def count_stores do
    Repo.aggregate(Store, :count)
  end

  @doc "Gets a store by id. Raises if not found."
  def get_store!(id), do: Repo.get!(Store, id)

  @doc "Gets a store by slug. Returns nil if not found."
  def get_store_by_slug(slug), do: Repo.get_by(Store, slug: slug)

  @doc "Creates a store and adds the creator as an admin member when scope is provided."
  def create_store(%Scope{} = current_scope, attrs) do
    Repo.transact(fn ->
      with {:ok, store} <-
             %Store{}
             |> Store.changeset(attrs)
             |> Repo.insert(),
           {:ok, _membership} <- create_owner_membership(current_scope, store) do
        {:ok, store}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def create_store(attrs) do
    %Store{}
    |> Store.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a store."
  def update_store(%Store{} = store, attrs) do
    store
    |> Store.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Returns a changeset for tracking create-form changes."
  def change_store(%Store{} = store, attrs \\ %{}) do
    Store.changeset(store, attrs)
  end

  @doc "Returns a changeset for tracking edit-form changes."
  def change_store_update(%Store{} = store, attrs \\ %{}) do
    Store.update_changeset(store, attrs)
  end

  defp create_owner_membership(%Scope{admin_user: %{id: admin_user_id}}, %Store{id: store_id}) do
    %StoreMembership{}
    |> StoreMembership.changeset(%{
      admin_user_id: admin_user_id,
      store_id: store_id,
      role: "admin"
    })
    |> Repo.insert()
  end

  defp create_owner_membership(%Scope{admin_user: nil}, _store) do
    {:error,
     Ecto.Changeset.add_error(
       Ecto.Changeset.change(%StoreMembership{}),
       :admin_user_id,
       "is required"
     )}
  end
end
