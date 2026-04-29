defmodule TesmoinWeb.SetupLive do
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
            Welcome to Tesmoin
            <:subtitle>
              Enter your email address to create your admin account and receive a sign-in link.
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

        <.form for={@form} id="setup_form" phx-submit="submit">
          <.input
            field={@form[:email]}
            type="email"
            label="Admin Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />
          <.button class="btn btn-primary w-full">
            Create admin account <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
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
      {:ok, assign(socket, form: form, client_ip: client_ip)}
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

                info = "Account created! Check your email for your sign-in link."

                {:noreply,
                 socket
                 |> put_flash(:info, info)
                 |> push_navigate(to: ~p"/admin_users/log-in")}

              {:error, reason} ->
                Logger.error("Setup: failed to enqueue magic link email",
                  email: email,
                  error: inspect(reason)
                )

                {:noreply,
                 socket
                 |> put_flash(
                   :error,
                   "Account created, but we could not queue your sign-in email. Please request a new sign-in link from the login page."
                 )
                 |> push_navigate(to: ~p"/admin_users/log-in")}
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
