defmodule TesmoinWeb.AdminUserLive.Login do
  use TesmoinWeb, :live_view

  require Logger

  alias Tesmoin.Accounts
  alias Tesmoin.RateLimiter

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
            Admin access
          </p>
          <h1 class="text-3xl font-semibold leading-tight text-slate-900 sm:text-4xl">
            Sign in to Tesmoin.
          </h1>
          <p class="max-w-lg text-sm leading-relaxed text-neutral-ink sm:text-base">
            We send a one-time magic link by email. No password reset flow, no credential reuse risks.
          </p>
          <div class="rounded-2xl border border-tertiary-300/70 bg-white/80 p-4 shadow-sm backdrop-blur-sm">
            <p class="text-sm font-medium text-slate-800">Secure by design</p>
            <ul class="mt-3 space-y-2 text-sm text-neutral-ink">
              <li class="flex items-start gap-2">
                <.icon name="hero-shield-check" class="mt-0.5 size-4 text-tertiary-600" />
                <span>Magic links expire quickly and are single use.</span>
              </li>
              <li class="flex items-start gap-2">
                <.icon name="hero-shield-check" class="mt-0.5 size-4 text-tertiary-600" />
                <span>Rate limiting protects login endpoints from abuse.</span>
              </li>
              <li class="flex items-start gap-2">
                <.icon name="hero-shield-check" class="mt-0.5 size-4 text-tertiary-600" />
                <span>All sessions are secured with HttpOnly cookies.</span>
              </li>
            </ul>
          </div>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <h2 class="text-xl font-semibold text-slate-900">Log in</h2>
          <p class="mt-2 text-sm text-neutral-ink">
            <%= if @current_scope do %>
              Reauthenticate to continue with this sensitive action.
            <% else %>
              Enter your admin email to receive a secure sign-in link.
            <% end %>
          </p>

          <div
            :if={local_mail_adapter?()}
            class="mt-5 rounded-xl border border-primary-200 bg-secondary-soft/90 p-3 text-sm text-slate-700"
          >
            <div class="flex items-start gap-2">
              <.icon name="hero-information-circle" class="mt-0.5 size-5 shrink-0 text-primary-700" />
              <p>
                Local mail adapter is active. Open
                <.link
                  href="/dev/mailbox"
                  class="font-semibold text-primary-700 underline decoration-primary-300 underline-offset-4"
                >
                  /dev/mailbox
                </.link>
                to inspect outgoing emails.
              </p>
            </div>
          </div>

          <.form
            for={@form}
            id="login_form_magic"
            action={~p"/admin_users/log-in"}
            phx-submit="submit_magic"
            class="mt-5 space-y-4"
          >
            <.input
              readonly={!!@current_scope}
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              spellcheck="false"
              class="backoffice-input"
              error_class="border-red-300 ring-red-200"
              required
              phx-mounted={JS.focus()}
            />
            <.button class="backoffice-button-primary mt-2 w-full">
              Send magic link <span aria-hidden="true">→</span>
            </.button>
          </.form>
        </div>
      </section>
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

          job_attrs = %{admin_user_id: admin_user.id}

          case enqueue_magic_link_email(job_attrs) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.error("Magic link enqueue failed",
                email: email,
                error: inspect(reason)
              )
          end
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

  defp enqueue_magic_link_email(job_attrs) do
    case job_attrs
         |> Tesmoin.Workers.MagicLinkMailer.new()
         |> Oban.insert() do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
