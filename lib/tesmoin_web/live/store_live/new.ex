defmodule TesmoinWeb.StoreLive.New do
  use TesmoinWeb, :live_view

  alias Tesmoin.Stores
  alias Tesmoin.Stores.Store

  def mount(_params, _session, socket) do
    changeset = Stores.change_store(%Store{})
    {:ok, assign(socket, form: to_form(changeset))}
  end

  def handle_event("validate", %{"store" => params}, socket) do
    params = maybe_autofill_slug(params)

    changeset =
      %Store{}
      |> Stores.change_store(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"store" => params}, socket) do
    case Stores.create_store(params) do
      {:ok, _store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store created successfully.")
         |> push_navigate(to: ~p"/stores")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  # Auto-fill slug from name when slug is still blank
  defp maybe_autofill_slug(%{"name" => name, "slug" => ""} = params) when name != "" do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    %{params | "slug" => slug}
  end

  defp maybe_autofill_slug(params), do: params

  def render(assigns) do
    ~H"""
    <Layouts.shell flash={@flash} current_scope={@current_scope} current_tab={:stores}>
      <div class="mx-auto max-w-xl">
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-slate-800">Add a store</h1>
          <p class="mt-1 text-sm text-slate-500">
            Connect an ecommerce storefront to this node. Each store has its own silo of reviews,
            orders, and analytics.
          </p>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <.form
            for={@form}
            id="store-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <.input field={@form[:name]} type="text" label="Store name" placeholder="My Shop" required />

            <div>
              <.input
                field={@form[:slug]}
                type="text"
                label="Slug"
                placeholder="my-shop"
                required
              />
              <p class="mt-1 text-xs text-slate-400">
                Lowercase letters, numbers, and hyphens only. Auto-filled from name.
              </p>
            </div>

            <.input
              field={@form[:primary_url]}
              type="url"
              label="Store URL"
              placeholder="https://myshop.com"
            />

            <div class="pt-2 flex gap-3">
              <.link navigate={~p"/"} class="backoffice-button-secondary px-5 py-2.5">
                Cancel
              </.link>
              <button type="submit" class="backoffice-button-primary flex-1 py-2.5">
                Create store
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.shell>
    """
  end
end
