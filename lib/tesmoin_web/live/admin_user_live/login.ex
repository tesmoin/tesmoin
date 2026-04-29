defmodule TesmoinWeb.AdminUserLive.Login do
  use TesmoinWeb, :live_view

  require Logger

  alias Tesmoin.Accounts
  alias Tesmoin.RateLimiter

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            <p>Log in</p>
            <:subtitle>
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% end %>
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form_magic"
          action={~p"/admin_users/log-in"}
          phx-submit="submit_magic"
        >
          <.input
            readonly={!!@current_scope}
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Log in with email <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:admin_user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "admin_user")

    client_ip =
      if connected?(socket) do
        case get_connect_info(socket, :peer_data) do
          %{address: ip} -> ip
          _ -> nil
        end
      end

    {:ok, assign(socket, form: form, client_ip: client_ip)}
  end

  @impl true
  def handle_event("submit_magic", %{"admin_user" => %{"email" => email}}, socket) do
    case RateLimiter.check_magic_link_request(socket.assigns.client_ip) do
      :rate_limited ->
        Logger.warning("Magic link rate limited",
          client_ip: inspect(socket.assigns.client_ip)
        )

        {:noreply,
         socket
         |> put_flash(:error, "Too many requests. Please wait a minute before trying again.")
         |> push_navigate(to: ~p"/admin_users/log-in")}

      :ok ->
        if admin_user = Accounts.get_admin_user_by_email(email) do
          Logger.info("Magic link requested", email: email)

          Accounts.deliver_login_instructions(
            admin_user,
            &url(~p"/admin_users/log-in/#{&1}")
          )
        end

        info =
          "If your email is in our system, you will receive instructions for logging in shortly."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> push_navigate(to: ~p"/admin_users/log-in")}
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:tesmoin, Tesmoin.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
