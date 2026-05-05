defmodule TesmoinWeb.UserLive.Login do
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
      minimal_chrome={true}
    >
      <section class="mx-auto max-w-md py-4 sm:py-10">
        <div class="mb-7 flex flex-col items-center gap-3 text-center">
          <img src={~p"/images/tesmoin-logo.png"} alt="Tesmoin" class="h-12 w-auto sm:h-14" />
          <h1 class="auth-brand-wordmark">Tesmoin</h1>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <%= if @magic_link_sent do %>
            <div class="flex flex-col items-center gap-4 py-6 text-center">
              <div class="flex size-14 items-center justify-center rounded-full bg-primary-100">
                <.icon name="hero-envelope" class="size-7 text-primary-700" />
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900">Check your inbox</p>
                <p class="mt-1 text-sm text-neutral-ink">
                  We sent a sign-in link to <span class="font-medium text-slate-800">{@login_email}</span>.
                </p>
                <p :if={@reauth_mode} class="mt-2 text-sm text-slate-600">
                  Use the link to re-authenticate and continue to your settings.
                </p>
              </div>

              <div
                :if={local_mail_adapter?()}
                class="w-full rounded-xl border border-primary-200 bg-secondary-soft/90 p-3 text-sm text-slate-700"
              >
                <div class="flex items-center gap-2">
                  <.icon name="hero-information-circle" class="size-5 shrink-0 text-primary-700" />
                  <p>
                    Using local adapter -
                    <.link
                      href="/dev/mailbox"
                      class="font-semibold text-primary-700 underline decoration-primary-300 underline-offset-4"
                    >
                      open mailbox
                    </.link>
                    to get your link.
                  </p>
                </div>
              </div>
            </div>
          <% else %>
            <div
              :if={@reauth_mode}
              class="mb-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900"
            >
              You must re-authenticate to access this page. Sensitive settings require confirmation every 10 minutes.
            </div>

            <p
              :if={@login_email}
              class="mb-4 rounded-xl border border-primary-200 bg-secondary-soft/70 px-3 py-2 text-sm text-slate-700"
            >
              Logging in as <span class="font-semibold text-slate-900">{@login_email}</span>.
            </p>

            <.form
              for={@form}
              id="login_form_magic"
              action={~p"/users/log-in"}
              phx-submit="submit_magic"
              class="space-y-4"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Email address"
                autocomplete="username"
                spellcheck="false"
                class="backoffice-input"
                error_class="border-red-300 ring-red-200"
                required
                phx-mounted={JS.focus()}
              />
              <.button class="backoffice-button-primary mt-2 w-full">
                Send magic link
              </.button>
            </.form>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    login_email = params["email"]
    reauth_mode = params["reauth"] == "true"
    form = to_form(%{"email" => login_email || ""}, as: "user")

    client_ip =
      if connected?(socket) do
        case get_connect_info(socket, :peer_data) do
          %{address: ip} -> ip
          _ -> nil
        end
      end

    {:ok,
     assign(socket,
       form: form,
       client_ip: client_ip,
       login_email: login_email,
       magic_link_sent: false,
       reauth_mode: reauth_mode
     )}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    case RateLimiter.check_magic_link_request(socket.assigns.client_ip) do
      :rate_limited ->
        Logger.warning("Magic link rate limited",
          client_ip: inspect(socket.assigns.client_ip)
        )

        {:noreply,
         socket
         |> put_flash(:error, "Too many requests. Please wait a minute before trying again.")
         |> push_navigate(to: ~p"/users/log-in")}

      :ok ->
        if user = Accounts.get_user_by_email(email) do
          Logger.info("Magic link requested", email: email)

          job_attrs = %{user_id: user.id, reauth: socket.assigns.reauth_mode}

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

        {:noreply,
         socket
         |> assign(login_email: email, magic_link_sent: true)}
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
