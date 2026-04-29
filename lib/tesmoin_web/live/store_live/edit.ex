defmodule TesmoinWeb.StoreLive.Edit do
  use TesmoinWeb, :live_view

  alias Tesmoin.Stores

  def mount(%{"id" => id}, _session, socket) do
    store = Stores.get_store!(id)
    changeset = Stores.change_store_update(store)
    {:ok, assign(socket, store: store, form: to_form(changeset))}
  end

  def handle_event("validate", %{"store" => params}, socket) do
    changeset =
      socket.assigns.store
      |> Stores.change_store_update(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"store" => params}, socket) do
    case Stores.update_store(socket.assigns.store, params) do
      {:ok, _store} ->
        {:noreply,
         socket
         |> put_flash(:info, "Store updated successfully.")
         |> push_navigate(to: ~p"/stores")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.shell
      flash={@flash}
      current_scope={@current_scope}
      current_tab={:stores}
      stores={@stores}
      current_store={@current_store}
    >
      <div class="mx-auto max-w-xl">
        <div class="mb-6 flex items-center gap-3">
          <.link navigate={~p"/stores"} class="text-slate-400 hover:text-slate-600 transition-colors">
            <.icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Edit store</h1>
            
            <p class="mt-0.5 text-sm text-slate-500 font-mono">/{@store.slug}</p>
          </div>
        </div>
        
        <div class="backoffice-card p-6 sm:p-8">
          <.form
            for={@form}
            id="store-edit-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-5"
          >
            <.input field={@form[:name]} type="text" label="Store name" required />
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Slug</label>
              <div class="flex items-center rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-400 font-mono cursor-not-allowed">
                /{@store.slug}
              </div>
              
              <p class="mt-1 text-xs text-slate-400">The slug cannot be changed after creation.</p>
            </div>
            
            <.input
              field={@form[:primary_url]}
              type="url"
              label="Store URL"
              placeholder="https://myshop.com"
            />
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Status</label>
              <div class="flex items-center rounded-lg border border-slate-200 bg-slate-50 px-3 py-2 text-sm text-slate-500 cursor-not-allowed">
                {String.capitalize(@store.status)}
              </div>
              
              <p class="mt-1 text-xs text-slate-400">
                Status can only be set when creating the store.
              </p>
            </div>
            
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Widget key</label>
              <div class="flex items-center gap-2 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2">
                <code class="flex-1 text-sm font-mono text-slate-600 select-all">
                  {@store.public_widget_key}
                </code> <.icon name="hero-key" class="size-4 shrink-0 text-slate-300" />
              </div>
              
              <p class="mt-1 text-xs text-slate-400">
                Use this key to initialise the embeddable review widget on your storefront.
              </p>
            </div>
            
            <div class="pt-2 flex gap-3">
              <.link navigate={~p"/stores"} class="backoffice-button-secondary px-5 py-2.5">
                Cancel
              </.link>
              <button type="submit" class="backoffice-button-primary flex-1 py-2.5">
                Save changes
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.shell>
    """
  end
end
