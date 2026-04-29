defmodule Tesmoin.Stores.Store do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stores" do
    field :name, :string
    field :slug, :string
    field :status, :string, default: "active"
    field :primary_url, :string
    field :public_widget_key, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating or updating a store."
  def changeset(store, attrs) do
    store
    |> cast(attrs, [:name, :slug, :status, :primary_url])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "can only contain lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:slug, min: 2, max: 80)
    |> validate_format(:primary_url, ~r/^https?:\/\/.+/,
      message: "must be a valid URL starting with http:// or https://"
    )
    |> unique_constraint(:slug)
    |> maybe_generate_widget_key()
  end

  defp maybe_generate_widget_key(changeset) do
    if changeset.valid? && get_field(changeset, :public_widget_key) == nil do
      put_change(changeset, :public_widget_key, generate_widget_key())
    else
      changeset
    end
  end

  defp generate_widget_key do
    :crypto.strong_rand_bytes(20) |> Base.encode32(case: :lower, padding: false)
  end
end
