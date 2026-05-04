defmodule TesmoinWeb.SetupLive do
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
            Initial setup
          </p>
          <h1 class="text-3xl font-semibold leading-tight text-slate-900 sm:text-4xl">
            Create your first admin user.
          </h1>
          <p class="max-w-lg text-sm leading-relaxed text-neutral-ink sm:text-base">
            This email receives a one-time sign-in link. Tesmoin uses passwordless authentication for
            a simpler and safer admin workflow.
          </p>
          <div class="rounded-2xl border border-primary-200/70 bg-white/75 p-4 shadow-sm backdrop-blur-sm">
            <p class="text-sm font-medium text-slate-800">What happens next</p>
            <ul class="mt-3 space-y-2 text-sm text-neutral-ink">
              <li class="flex items-start gap-2">
                <.icon name="hero-check-circle" class="mt-0.5 size-4 text-primary-700" />
                <span>Account is created and confirmed immediately.</span>
              </li>
              <li class="flex items-start gap-2">
                <.icon name="hero-check-circle" class="mt-0.5 size-4 text-primary-700" />
                <span>A secure magic link is delivered by email.</span>
              </li>
              <li class="flex items-start gap-2">
                <.icon name="hero-check-circle" class="mt-0.5 size-4 text-primary-700" />
                <span>You can start configuring your store(s) and reviews right away.</span>
              </li>
            </ul>
          </div>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <h2 class="text-xl font-semibold text-slate-900">Welcome to Tesmoin</h2>
          <p class="mt-2 text-sm text-neutral-ink">
            Enter the admin email to receive your first sign-in link.
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

          <%= if @setup_done do %>
            <div class="mt-5 flex flex-col items-center gap-4 py-6 text-center">
              <div class="flex size-14 items-center justify-center rounded-full bg-primary-100">
                <.icon name="hero-envelope" class="size-7 text-primary-700" />
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900">Check your inbox</p>
                <p class="mt-1 text-sm text-neutral-ink">
                  We sent a sign-in link to <span class="font-medium text-slate-800">{@setup_email}</span>.
                </p>
              </div>
              <div
                :if={local_mail_adapter?()}
                class="w-full rounded-xl border border-primary-200 bg-secondary-soft/90 p-3 text-sm text-slate-700"
              >
                <div class="flex items-center gap-2">
                  <.icon name="hero-information-circle" class="size-5 shrink-0 text-primary-700" />
                  <p>
                    Using local adapter —
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
            <.form for={@form} id="setup_form" phx-submit="submit" class="mt-5 space-y-4">
              <.input
                field={@form[:email]}
                type="email"
                label="Admin Email"
                autocomplete="username"
                spellcheck="false"
                class="backoffice-input"
                error_class="border-red-300 ring-red-200"
                required
                phx-mounted={JS.focus()}
              />
              <.button class="backoffice-button-primary mt-2 w-full">
                Create admin account <span aria-hidden="true">→</span>
              </.button>
            </.form>
          <% end %>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if Accounts.admin_user_exists?() do
      {:ok, push_navigate(socket, to: ~p"/admin_users/log-in")}
    else
      client_ip =
        if connected?(socket) do
          case get_connect_info(socket, :peer_data) do
            %{address: ip} -> ip
            _ -> nil
          end
        end

      form = to_form(%{"email" => ""}, as: "admin_user")
      {:ok, assign(socket, form: form, client_ip: client_ip, setup_done: false, setup_email: nil)}
    end
  end

  @impl true
  def handle_event("submit", %{"admin_user" => %{"email" => email}}, socket) do
    case RateLimiter.check_magic_link_request(socket.assigns.client_ip) do
      :rate_limited ->
        Logger.warning("Setup rate limited", client_ip: inspect(socket.assigns.client_ip))

        {:noreply,
         put_flash(socket, :error, "Too many requests. Please wait a minute before trying again.")}

      :ok ->
        case Accounts.register_first_admin_user(%{email: email}) do
          {:ok, admin_user} ->
            {:ok, _} = Accounts.confirm_admin_user(admin_user)

            job_attrs = %{admin_user_id: admin_user.id}

            case enqueue_magic_link_email(job_attrs) do
              :ok ->
                Logger.info("Setup: first admin account created", email: email)

                {:noreply, assign(socket, setup_done: true, setup_email: email)}

              {:error, reason} ->
                Logger.error("Setup: failed to enqueue magic link email",
                  email: email,
                  error: inspect(reason)
                )

                {:noreply,
                 put_flash(
                   socket,
                   :error,
                   "Account created, but we could not queue your sign-in email. Please request a new sign-in link from the login page."
                 )}
            end

          {:error, :already_setup} ->
            Logger.warning("Setup: concurrent request detected, admin already exists")
            {:noreply, push_navigate(socket, to: ~p"/admin_users/log-in")}

          {:error, changeset} ->
            {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
        end
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
