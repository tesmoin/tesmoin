defmodule TesmoinWeb.SetupLive do
  use TesmoinWeb, :live_view

  alias Tesmoin.Accounts

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
      form = to_form(%{"email" => ""}, as: "admin_user")
      {:ok, assign(socket, form: form)}
    end
  end

  @impl true
  def handle_event("submit", %{"admin_user" => %{"email" => email}}, socket) do
    case Accounts.register_admin_user(%{email: email}) do
      {:ok, admin_user} ->
        {:ok, _} = Accounts.confirm_admin_user(admin_user)

        Accounts.deliver_login_instructions(
          admin_user,
          &url(~p"/admin_users/log-in/#{&1}")
        )

        info = "Account created! Check your email for your sign-in link."

        {:noreply,
         socket
         |> put_flash(:info, info)
         |> push_navigate(to: ~p"/admin_users/log-in")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:tesmoin, Tesmoin.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
