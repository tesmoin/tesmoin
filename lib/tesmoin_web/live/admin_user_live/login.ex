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
      minimal_chrome={true}
    >
      <section class="mx-auto max-w-md py-4 sm:py-10">
        <div class="mb-7 flex flex-col items-center gap-3 text-center">
          <img src={~p"/images/tesmoin-logo.png"} alt="Tesmoin" class="h-12 w-auto sm:h-14" />
          <h1 class="auth-brand-wordmark">Tesmoin</h1>
        </div>

        <div class="backoffice-card p-6 sm:p-8">
          <.form
            for={@form}
            id="login_form_magic"
            action={~p"/admin_users/log-in"}
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
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"email" => ""}, as: "admin_user")

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

  defp enqueue_magic_link_email(job_attrs) do
    case job_attrs
         |> Tesmoin.Workers.MagicLinkMailer.new()
         |> Oban.insert() do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
