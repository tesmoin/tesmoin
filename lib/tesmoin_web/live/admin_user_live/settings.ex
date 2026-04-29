defmodule TesmoinWeb.AdminUserLive.Settings do
  use TesmoinWeb, :live_view

  on_mount {TesmoinWeb.AdminUserAuth, :require_sudo_mode}

  alias Tesmoin.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="text-center">
        <.header>
          Account Settings
          <:subtitle>Manage your account email address</:subtitle>
        </.header>
      </div>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          spellcheck="false"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_admin_user_email(socket.assigns.current_scope.admin_user, token) do
        {:ok, _admin_user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/admin_users/settings")}
  end

  def mount(_params, _session, socket) do
    admin_user = socket.assigns.current_scope.admin_user
    email_changeset = Accounts.change_admin_user_email(admin_user, %{}, validate_unique: false)

    socket =
      socket
      |> assign(:current_email, admin_user.email)
      |> assign(:email_form, to_form(email_changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"admin_user" => admin_user_params} = params

    email_form =
      socket.assigns.current_scope.admin_user
      |> Accounts.change_admin_user_email(admin_user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"admin_user" => admin_user_params} = params
    admin_user = socket.assigns.current_scope.admin_user
    true = Accounts.sudo_mode?(admin_user)

    case Accounts.change_admin_user_email(admin_user, admin_user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_admin_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          admin_user.email,
          &url(~p"/admin_users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end
end
