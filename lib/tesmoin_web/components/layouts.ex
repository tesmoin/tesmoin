defmodule TesmoinWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TesmoinWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :hide_public_auth_action, :boolean,
    default: false,
    doc: "hides the public log in CTA on auth-focused screens"

  attr :minimal_chrome, :boolean,
    default: false,
    doc: "hides app chrome (header/nav) for focused auth pages"

  attr :stores, :list, default: []
  attr :current_store, :map, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="relative min-h-screen overflow-hidden">
      <div class="absolute inset-0 -z-10 backoffice-mesh"></div>
      <div class={[
        "mx-auto max-w-7xl px-4 pb-10 sm:px-6 lg:px-8",
        if(@minimal_chrome, do: "pt-10 sm:pt-14", else: "pt-6")
      ]}>
        <header
          :if={!@minimal_chrome}
          class="backoffice-shell mb-8 flex flex-wrap items-center justify-between gap-4 px-4 py-3 sm:px-5"
        >
          <a href={~p"/"} class="flex items-center gap-3">
            <img src={~p"/images/tesmoin-logo.png"} alt="Tesmoin" class="h-10 w-auto" />
            <h1 class="auth-brand-wordmark auth-brand-wordmark-nav">Tesmoin</h1>
          </a>

          <nav class="flex flex-wrap items-center gap-3">
            <%= if @current_scope do %>
              <%!-- Store selector --%>
              <form
                id="store-switch-form"
                action="/stores/switch"
                method="post"
                class="flex items-center"
              >
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <select
                  id="store-switcher"
                  name="store_id"
                  phx-hook=".StoreSwitcher"
                  disabled={@stores == []}
                  class="rounded-lg border border-[color-mix(in_oklab,var(--tes-primary)_22%,white)] bg-white/80 px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--tes-primary)_30%,white)] cursor-pointer disabled:cursor-not-allowed disabled:bg-slate-100 disabled:text-slate-400"
                >
                  <%= if @stores == [] do %>
                    <option value="">No accessible stores</option>
                  <% else %>
                    <%= for store <- @stores do %>
                      <option
                        value={store.id}
                        selected={@current_store && @current_store.id == store.id}
                      >
                        {store.name}
                      </option>
                    <% end %>
                  <% end %>
                </select>
              </form>

              <span class="hidden rounded-full bg-white px-3 py-1 text-xs font-medium text-neutral-ink shadow-sm sm:inline">
                {@current_scope.admin_user.email}
              </span>
            <% else %>
              <%= unless @hide_public_auth_action do %>
                <.link href={~p"/admin_users/log-in"} class="backoffice-button-primary">Log in</.link>
              <% end %>
            <% end %>
          </nav>
        </header>

        <main>
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />

    <script :type={Phoenix.LiveView.ColocatedHook} name=".StoreSwitcher">
      export default {
        mounted() {
          if (this.el.disabled) return

          this.el.addEventListener("change", () => {
            document.getElementById("store-switch-form").submit()
          })
        }
      }
    </script>
    """
  end

  @nav_items [
    %{id: :dashboard, label: "Dashboard", icon: "hero-squares-2x2", path: "/"},
    %{id: :stores, label: "Stores", icon: "hero-building-storefront", path: "/stores"},
    %{id: :team, label: "Team", icon: "hero-users", path: "/team"},
    %{id: :settings, label: "Settings", icon: "hero-cog-6-tooth", path: "/admin_users/settings"}
  ]

  @doc """
  Renders the authenticated two-column shell: sticky sidebar on the left,
  main content area on the right. Wraps `Layouts.app`.

  ## Examples

      <Layouts.shell flash={@flash} current_scope={@current_scope} current_tab={:dashboard}>
        <h2>Dashboard</h2>
      </Layouts.shell>

  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_tab, :atom, required: true
  attr :stores, :list, default: []
  attr :current_store, :map, default: nil
  slot :inner_block, required: true

  def shell(assigns) do
    assigns = assign(assigns, :nav_items, @nav_items)

    ~H"""
    <.app
      flash={@flash}
      current_scope={@current_scope}
      stores={@stores}
      current_store={@current_store}
    >
      <div class="flex gap-6 items-start">
        <aside class="w-52 shrink-0 sticky top-6">
          <nav class="backoffice-shell p-2 flex flex-col gap-0.5">
            <%= for item <- @nav_items do %>
              <.link
                navigate={item.path}
                class={[
                  "flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm transition-all duration-150",
                  if(@current_tab == item.id,
                    do: "sidebar-nav-active",
                    else:
                      "font-medium text-slate-600 hover:bg-[color-mix(in_oklab,var(--tes-secondary)_70%,white)] hover:text-slate-800"
                  )
                ]}
              >
                <.icon
                  name={item.icon}
                  class={[
                    "size-4 shrink-0",
                    if(@current_tab == item.id, do: "text-white", else: "text-slate-400")
                  ]}
                />
                {item.label}
              </.link>
            <% end %>
          </nav>
        </aside>

        <div class="flex-1 min-w-0">
          {render_slot(@inner_block)}
        </div>
      </div>
    </.app>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
