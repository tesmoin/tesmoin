defmodule TesmoinWeb.DashboardLive do
  use TesmoinWeb, :live_view

  alias Tesmoin.Stores

  @nav_items [
    %{id: :dashboard, label: "Dashboard", icon: "hero-squares-2x2", path: "/"},
    %{id: :stores, label: "Stores", icon: "hero-building-storefront", path: "/stores"},
    %{id: :reviews, label: "Reviews", icon: "hero-star", path: "/reviews"},
    %{id: :questions, label: "Q&A", icon: "hero-chat-bubble-left-right", path: "/questions"},
    %{id: :moderation, label: "Moderation", icon: "hero-shield-check", path: "/moderation"},
    %{id: :analytics, label: "Analytics", icon: "hero-chart-bar", path: "/analytics"},
    %{id: :settings, label: "Settings", icon: "hero-cog-6-tooth", path: "/admin_users/settings"}
  ]

  def mount(_params, _session, socket) do
    store_count = Stores.count_stores()
    {:ok, assign(socket, store_count: store_count, active_tab: :dashboard, nav_items: @nav_items)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex gap-6 items-start">
        <%!-- Left sidebar --%>
        <aside class="w-52 shrink-0 sticky top-6">
          <nav class="backoffice-shell p-2 flex flex-col gap-0.5">
            <%= for item <- @nav_items do %>
              <.link
                navigate={item.path}
                class={[
                  "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-150",
                  if(@active_tab == item.id,
                    do: "bg-[--tes-primary] text-white shadow-sm",
                    else:
                      "text-slate-600 hover:bg-[color-mix(in_oklab,var(--tes-secondary)_70%,white)] hover:text-slate-800"
                  )
                ]}
              >
                <.icon
                  name={item.icon}
                  class={[
                    "size-4 shrink-0",
                    if(@active_tab == item.id, do: "text-white", else: "text-slate-400")
                  ]}
                />
                {item.label}
              </.link>
            <% end %>
          </nav>
        </aside>

        <%!-- Main content --%>
        <div class="flex-1 min-w-0">
          <%= if @active_tab == :dashboard do %>
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
                  href="/stores/new"
                  class="backoffice-button-primary inline-flex items-center gap-2 px-5 py-2.5"
                >
                  <.icon name="hero-plus" class="size-4" />
                  Add your first store
                </.link>
              </div>
            <% else %>
              <%!-- Dashboard with stores: placeholder for stats --%>
              <div class="backoffice-card px-6 py-8">
                <h2 class="text-lg font-bold text-slate-800">Dashboard</h2>
                <p class="mt-1 text-sm text-slate-500">
                  You have {@store_count} {if @store_count == 1, do: "store", else: "stores"} connected.
                </p>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
