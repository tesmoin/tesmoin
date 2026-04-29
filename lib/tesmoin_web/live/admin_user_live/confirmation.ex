defmodule TesmoinWeb.AdminUserLive.Confirmation do
  use TesmoinWeb, :live_view

  alias Tesmoin.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      hide_public_auth_action={true}
    >
      <section class="mx-auto grid max-w-5xl gap-8 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
        <div class="space-y-5">
          <p class="inline-flex items-center rounded-full bg-white/80 px-4 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-primary-700 shadow-sm">
            Secure access
          </p>
          <h1 class="text-3xl font-semibold leading-tight text-slate-900 sm:text-4xl">
            Finish signing in with your magic link.
          </h1>
          <p class="max-w-lg text-sm leading-relaxed text-neutral-ink sm:text-base">
            You are authenticating as {@admin_user.email}. Choose whether this device should stay signed in.
          </p>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <h2 class="text-xl font-semibold text-slate-900">Welcome {@admin_user.email}</h2>
          <p class="mt-2 text-sm text-neutral-ink">
            Confirm this sign-in session to continue.
          </p>

          <.form
            :if={!@admin_user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/admin_users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="mt-5 space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirming..."
              class="backoffice-button-primary w-full"
            >
              Confirm and stay logged in
            </.button>
            <.button
              phx-disable-with="Confirming..."
              class="backoffice-button-secondary w-full"
            >
              Confirm and log in only this time
            </.button>
          </.form>

          <.form
            :if={@admin_user.confirmed_at}
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/admin_users/log-in"}
            phx-trigger-action={@trigger_submit}
            class="mt-5 space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <%= if @current_scope do %>
              <.button phx-disable-with="Logging in..." class="backoffice-button-primary w-full">
                Log in
              </.button>
            <% else %>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                class="backoffice-button-primary w-full"
              >
                Keep me logged in on this device
              </.button>
              <.button phx-disable-with="Logging in..." class="backoffice-button-secondary w-full">
                Log me in only this time
              </.button>
            <% end %>
          </.form>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if admin_user = Accounts.get_admin_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "admin_user")

      {:ok, assign(socket, admin_user: admin_user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/admin_users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"admin_user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "admin_user"), trigger_submit: true)}
  end
end
