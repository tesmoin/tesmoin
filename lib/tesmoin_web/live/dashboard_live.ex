defmodule TesmoinWeb.DashboardLive do
  use TesmoinWeb, :live_view

  def mount(_params, _session, socket) do
    store_count = length(socket.assigns.stores || [])
    {:ok, assign(socket, store_count: store_count)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.shell
      flash={@flash}
      current_scope={@current_scope}
      current_tab={:dashboard}
      stores={@stores}
      current_store={@current_store}
    >
      <%= if @store_count == 0 do %>
        <%!-- Empty state: no stores yet --%>
        <div class="backoffice-card flex flex-col items-center justify-center gap-6 px-8 py-16 text-center">
          <div class="flex size-20 items-center justify-center rounded-2xl bg-[color-mix(in_oklab,var(--tes-secondary)_80%,white)] border border-[color-mix(in_oklab,var(--tes-primary)_18%,white)]">
            <.icon name="hero-building-storefront" class="size-10 text-[--tes-primary]" />
          </div>

          <div class="max-w-sm">
            <h2 class="text-xl font-bold text-slate-800">Set up your first store</h2>

            <p class="mt-2 text-sm text-slate-500 leading-relaxed">
              Before you can collect reviews, process transactions, or send review requests,
              you need to connect at least one store to this node.
            </p>
          </div>

          <.link
            navigate={~p"/stores/new"}
            class="backoffice-button-primary inline-flex items-center gap-2 px-5 py-2.5"
          >
            <.icon name="hero-plus" class="size-4" /> Add your first store
          </.link>
        </div>
      <% else %>
        <%!-- Dashboard placeholder --%>
        <div class="backoffice-card px-6 py-8">
          <h2 class="text-lg font-bold text-slate-800">Dashboard</h2>

          <p class="mt-1 text-sm text-slate-500">
            You have {@store_count} {if @store_count == 1, do: "store", else: "stores"} connected.
          </p>
        </div>
      <% end %>
    </Layouts.shell>
    """
  end
end
