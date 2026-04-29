defmodule TesmoinWeb.StoreLive.Index do
  use TesmoinWeb, :live_view

  alias Tesmoin.Stores

  def mount(_params, _session, socket) do
    stores = Stores.list_stores()
    {:ok, assign(socket, stores: stores, confirm_archive_id: nil)}
  end

  def handle_event("archive", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirm_archive_id: String.to_integer(id))}
  end

  def handle_event("cancel-archive", _params, socket) do
    {:noreply, assign(socket, confirm_archive_id: nil)}
  end

  def handle_event("confirm-archive", %{"id" => id}, socket) do
    store = Stores.get_store!(String.to_integer(id))

    case Stores.archive_store(store) do
      {:ok, _store} ->
        stores = Stores.list_stores()
        {:noreply, assign(socket, stores: stores, confirm_archive_id: nil)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not archive store.")
         |> assign(confirm_archive_id: nil)}
    end
  end

  def handle_event("activate", %{"id" => id}, socket) do
    store = Stores.get_store!(String.to_integer(id))

    case Stores.activate_store(store) do
      {:ok, _store} ->
        stores = Stores.list_stores()
        {:noreply, assign(socket, stores: stores)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not activate store.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.shell flash={@flash} current_scope={@current_scope} current_tab={:stores}>
      <div class="space-y-5">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Stores</h1>
            <p class="mt-1 text-sm text-slate-500">
              Each store is an independent ecommerce site with its own reviews and data.
            </p>
          </div>
          <.link
            navigate={~p"/stores/new"}
            class="backoffice-button-primary inline-flex items-center gap-2 px-4 py-2.5"
          >
            <.icon name="hero-plus" class="size-4" />
            Add store
          </.link>
        </div>

        <%!-- Empty state --%>
        <div :if={@stores == []} class="backoffice-card flex flex-col items-center gap-5 px-8 py-14 text-center">
          <div class="flex size-16 items-center justify-center rounded-2xl bg-[color-mix(in_oklab,var(--tes-secondary)_80%,white)] border border-[color-mix(in_oklab,var(--tes-primary)_18%,white)]">
            <.icon name="hero-building-storefront" class="size-8 text-[--tes-primary]" />
          </div>
          <div class="max-w-sm">
            <p class="font-semibold text-slate-800">No stores yet</p>
            <p class="mt-1 text-sm text-slate-500">Add your first store to start collecting reviews and processing orders.</p>
          </div>
          <.link navigate={~p"/stores/new"} class="backoffice-button-primary inline-flex items-center gap-2 px-5 py-2.5">
            <.icon name="hero-plus" class="size-4" />
            Add your first store
          </.link>
        </div>

        <%!-- Store list --%>
        <div :if={@stores != []} class="space-y-3">
          <%= for store <- @stores do %>
            <div class={[
              "backoffice-card px-5 py-4",
              store.status == "archived" && "opacity-60"
            ]}>
              <div class="flex items-start justify-between gap-4">
                <%!-- Info --%>
                <div class="flex items-start gap-4 min-w-0">
                  <div class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-[color-mix(in_oklab,var(--tes-secondary)_80%,white)] border border-[color-mix(in_oklab,var(--tes-primary)_18%,white)]">
                    <.icon name="hero-building-storefront" class="size-5 text-[--tes-primary]" />
                  </div>
                  <div class="min-w-0">
                    <div class="flex items-center gap-2 flex-wrap">
                      <span class="font-semibold text-slate-800">{store.name}</span>
                      <span class="rounded-full bg-slate-100 px-2 py-0.5 text-xs font-mono text-slate-500">
                        /{store.slug}
                      </span>
                      <span :if={store.status == "archived"} class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">
                        Archived
                      </span>
                    </div>
                    <p :if={store.primary_url} class="mt-0.5 text-sm text-slate-500 truncate">
                      <a href={store.primary_url} target="_blank" rel="noopener noreferrer" class="hover:underline hover:text-slate-700">
                        {store.primary_url}
                      </a>
                    </p>
                    <p :if={!store.primary_url} class="mt-0.5 text-xs text-slate-400 italic">
                      No URL configured
                    </p>
                    <div class="mt-2 flex items-center gap-2 flex-wrap">
                      <span class="text-xs text-slate-400">Widget key:</span>
                      <code class="rounded bg-slate-100 px-1.5 py-0.5 text-xs font-mono text-slate-600 select-all">
                        {store.public_widget_key}
                      </code>
                    </div>
                  </div>
                </div>

                <%!-- Actions --%>
                <div class="flex shrink-0 items-center gap-2">
                  <%= if @confirm_archive_id == store.id do %>
                    <span class="text-sm text-slate-600 mr-1">Archive this store?</span>
                    <button
                      phx-click="confirm-archive"
                      phx-value-id={store.id}
                      class="rounded-lg bg-red-50 border border-red-200 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-100 transition-colors"
                    >
                      Confirm
                    </button>
                    <button
                      phx-click="cancel-archive"
                      class="rounded-lg bg-slate-50 border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors"
                    >
                      Cancel
                    </button>
                  <% else %>
                    <.link
                      navigate={~p"/stores/#{store.id}/edit"}
                      class="rounded-lg bg-slate-50 border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors inline-flex items-center gap-1.5"
                    >
                      <.icon name="hero-pencil-square" class="size-3.5" />
                      Edit
                    </.link>
                    <%= if store.status == "active" do %>
                      <button
                        phx-click="archive"
                        phx-value-id={store.id}
                        class="rounded-lg bg-slate-50 border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-500 hover:bg-amber-50 hover:border-amber-200 hover:text-amber-700 transition-colors inline-flex items-center gap-1.5"
                      >
                        <.icon name="hero-archive-box" class="size-3.5" />
                        Archive
                      </button>
                    <% else %>
                      <button
                        phx-click="activate"
                        phx-value-id={store.id}
                        class="rounded-lg bg-emerald-50 border border-emerald-200 px-3 py-1.5 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 transition-colors inline-flex items-center gap-1.5"
                      >
                        <.icon name="hero-arrow-path" class="size-3.5" />
                        Reactivate
                      </button>
                    <% end %>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.shell>
    """
  end
end
