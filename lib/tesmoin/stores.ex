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

  @doc "Returns all stores."
  def list_stores do
    Repo.all(from s in Store, order_by: [asc: s.inserted_at])
  end

  @doc "Returns all stores accessible to a user (all stores, membership is not enforced)."
  def list_stores_for_user(_user_id), do: list_stores()

  @doc "Returns the total number of stores on this node."
  def count_stores do
    Repo.aggregate(Store, :count)
  end

  @doc "Gets a store by id. Raises if not found."
  def get_store!(id), do: Repo.get!(Store, id)

  @doc "Gets a store by slug. Returns nil if not found."
  def get_store_by_slug(slug), do: Repo.get_by(Store, slug: slug)

  @doc "Creates a store."
  def create_store(%Scope{} = _current_scope, attrs) do
    create_store(attrs)
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
end
