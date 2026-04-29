defmodule TesmoinWeb.StoreLive.Index do
  use TesmoinWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
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
      <div class="space-y-5">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Stores</h1>

            <p class="mt-1 text-sm text-slate-500">
              Each store is an independent ecommerce site with its own dataset.
            </p>
          </div>

          <.link
            navigate={~p"/stores/new"}
            class="backoffice-button-primary inline-flex items-center gap-2 px-4 py-2.5"
          >
            <.icon name="hero-plus" class="size-4" /> Add store
          </.link>
        </div>
        <%!-- Empty state --%>
        <div
          :if={@stores == []}
          class="backoffice-card flex flex-col items-center gap-5 px-8 py-14 text-center"
        >
          <div class="flex size-16 items-center justify-center rounded-2xl bg-[color-mix(in_oklab,var(--tes-secondary)_80%,white)] border border-[color-mix(in_oklab,var(--tes-primary)_18%,white)]">
            <.icon name="hero-building-storefront" class="size-8 text-[--tes-primary]" />
          </div>

          <div class="max-w-sm">
            <p class="font-semibold text-slate-800">No stores yet</p>

            <p class="mt-1 text-sm text-slate-500">
              Add your first store to start collecting reviews and processing orders.
            </p>
          </div>

          <.link
            navigate={~p"/stores/new"}
            class="backoffice-button-primary inline-flex items-center gap-2 px-5 py-2.5"
          >
            <.icon name="hero-plus" class="size-4" /> Add your first store
          </.link>
        </div>
        <%!-- Store list --%>
        <div :if={@stores != []} class="space-y-3">
          <%= for store <- @stores do %>
            <div class="backoffice-card px-5 py-4">
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
                      <span class={[
                        "rounded-full px-2 py-0.5 text-xs font-semibold",
                        if(store.status == "live",
                          do: "bg-emerald-100 text-emerald-700",
                          else: "bg-indigo-100 text-indigo-700"
                        )
                      ]}>
                        {String.capitalize(store.status)}
                      </span>
                    </div>

                    <p :if={store.primary_url} class="mt-0.5 text-sm text-slate-500 truncate">
                      <a
                        href={store.primary_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        class="hover:underline hover:text-slate-700"
                      >
                        {store.primary_url}
                      </a>
                    </p>

                    <p :if={!store.primary_url} class="mt-0.5 text-xs text-slate-400 italic">
                      No URL configured
                    </p>

                    <div class="mt-2 flex items-center gap-2 flex-wrap">
                      <span class="text-xs text-slate-400">Widget key:</span>
                      <button
                        id={"copy-key-#{store.id}"}
                        phx-hook=".CopyWidgetKey"
                        data-key={store.public_widget_key}
                        title="Click to copy"
                        class="group inline-flex items-center gap-1.5 rounded-md bg-slate-100 px-1.5 py-0.5 hover:bg-violet-50 hover:ring-1 hover:ring-violet-200 transition-all cursor-pointer"
                      >
                        <code class="text-xs font-mono text-slate-600 group-hover:text-violet-700 transition-colors">
                          {store.public_widget_key}
                        </code>
                        <.icon
                          name="hero-clipboard"
                          class="size-3 shrink-0 text-slate-400 group-hover:text-violet-500 transition-colors"
                        /> <span data-copy-icon="true" class="contents"></span>
                      </button>
                      <span
                        id={"copy-confirm-#{store.id}"}
                        class="hidden text-xs font-medium text-emerald-600"
                      >
                        Copied!
                      </span>
                    </div>
                  </div>
                </div>
                <%!-- Actions --%>
                <div class="flex shrink-0 items-center gap-2">
                  <.link
                    navigate={~p"/stores/#{store.id}/edit"}
                    class="rounded-lg bg-slate-50 border border-slate-200 px-3 py-1.5 text-xs font-semibold text-slate-600 hover:bg-slate-100 transition-colors inline-flex items-center gap-1.5"
                  >
                    <.icon name="hero-pencil-square" class="size-3.5" /> Edit
                  </.link>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.shell>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyWidgetKey">
      export default {
        mounted() {
          this.el.addEventListener("click", () => {
            navigator.clipboard.writeText(this.el.dataset.key).then(() => {
              const storeId = this.el.id.replace("copy-key-", "")
              const confirm = document.getElementById("copy-confirm-" + storeId)
              if (confirm) {
                confirm.classList.remove("hidden")
                setTimeout(() => confirm.classList.add("hidden"), 2000)
              }
            })
          })
        }
      }
    </script>
    """
  end
end
