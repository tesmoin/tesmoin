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
      minimal_chrome={true}
    >
      <section class="mx-auto max-w-md py-4 sm:py-10">
        <div class="mb-7 flex flex-col items-center gap-3 text-center">
          <img src={~p"/images/tesmoin-logo.png"} alt="Tesmoin" class="h-12 w-auto sm:h-14" />
          <h1 class="auth-brand-wordmark">Tesmoin</h1>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <p class="mb-4 rounded-xl border border-primary-200 bg-secondary-soft/70 px-3 py-2 text-sm text-slate-700">
            Logging in as <span class="font-semibold text-slate-900">{@admin_user.email}</span>.
          </p>

          <.form
            :if={!@admin_user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/admin_users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
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
            class="space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <%= if @current_scope do %>
              <.button
                phx-disable-with="Logging in..."
                class="backoffice-button-primary w-full"
              >
                {if @reauth_mode, do: "Re-authenticate", else: "Log in"}
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
  def mount(%{"token" => token} = params, _session, socket) do
    if admin_user = Accounts.get_admin_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "admin_user")
      reauth_mode = params["reauth"] == "true"

      {:ok,
       assign(socket,
         admin_user: admin_user,
         form: form,
         trigger_submit: false,
         reauth_mode: reauth_mode
       ), temporary_assigns: [form: nil]}
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
