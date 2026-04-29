defmodule TesmoinWeb.AdminUserLive.Registration do
  use TesmoinWeb, :live_view

  alias Tesmoin.Accounts
  alias Tesmoin.Accounts.AdminUser

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div class="text-center">
          <.header>
            Register for an account
            <:subtitle>
              Already registered?
              <.link
                navigate={~p"/admin_users/log-in"}
                class="font-semibold text-brand hover:underline"
              >
                Log in
              </.link>
              to your account now.
            </:subtitle>
          </.header>
        </div>

        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />

          <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
            Create an account
          </.button>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{admin_user: admin_user}}} = socket)
      when not is_nil(admin_user) do
    {:ok, redirect(socket, to: TesmoinWeb.AdminUserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_admin_user_email(%AdminUser{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"admin_user" => admin_user_params}, socket) do
    case Accounts.register_admin_user(admin_user_params) do
      {:ok, admin_user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            admin_user,
            &url(~p"/admin_users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{admin_user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/admin_users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"admin_user" => admin_user_params}, socket) do
    changeset =
      Accounts.change_admin_user_email(%AdminUser{}, admin_user_params, validate_unique: false)

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "admin_user")
    assign(socket, form: form)
  end
end
