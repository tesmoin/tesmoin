defmodule TesmoinWeb.AdminUserLive.Settings do
  use TesmoinWeb, :live_view

  on_mount {TesmoinWeb.AdminUserAuth, :require_sudo_mode}

  alias Tesmoin.Accounts
  alias Tesmoin.Team

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.shell
      flash={@flash}
      current_scope={@current_scope}
      current_tab={:settings}
      stores={@stores}
      current_store={@current_store}
    >
      <div class="space-y-6">
        <%!-- Change email --%>
        <div class="backoffice-card p-6">
          <h2 class="text-base font-semibold text-slate-800 mb-1">Email address</h2>

          <p class="text-sm text-slate-500 mb-5">
            Current: <span class="font-medium text-slate-700">{@current_email}</span>
          </p>

          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="flex flex-col gap-4 max-w-md"
          >
            <.input
              field={@email_form[:email]}
              type="email"
              label="New email"
              autocomplete="username"
              spellcheck="false"
              required
            />
            <div>
              <.button variant="primary" phx-disable-with="Sending link...">Change email</.button>
            </div>
          </.form>
        </div>
        <%!-- Log out --%>
        <div class="backoffice-card p-6">
          <h2 class="text-base font-semibold text-slate-800 mb-1">Session</h2>

          <p class="text-sm text-slate-500 mb-5">Sign out of your account on this device.</p>

          <.link
            href={~p"/admin_users/log-out"}
            method="delete"
            class="inline-flex items-center gap-2 rounded-xl bg-red-50 px-4 py-2 text-sm font-semibold text-red-600 ring-1 ring-inset ring-red-200 hover:bg-red-100 transition-colors"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-4" /> Log out
          </.link>
        </div>
        <%!-- Delete account --%>
        <div class="backoffice-card p-6 border border-red-100">
          <h2 class="text-base font-semibold text-red-700 mb-1">Delete account</h2>

          <p class="text-sm text-slate-500 mb-5">
            This permanently removes your account and revokes all your store access.
          </p>

          <form id="delete-account-form" phx-submit="open-delete-modal">
            <button
              type="submit"
              class="inline-flex items-center gap-2 rounded-xl bg-red-600 px-4 py-2 text-sm font-semibold text-white hover:bg-red-700 transition-colors"
            >
              <.icon name="hero-trash" class="size-4" /> Delete my account
            </button>
          </form>
        </div>
      </div>

      <div :if={@show_delete_modal} class="fixed inset-0 z-50">
        <div
          class="absolute inset-0 bg-slate-900/45 backdrop-blur-[1px]"
          phx-click="cancel-delete-modal"
        >
        </div>

        <div class="relative flex min-h-full items-center justify-center p-4">
          <div class="w-full max-w-md rounded-2xl border border-red-200 bg-white shadow-2xl">
            <div class="p-6">
              <div class="mb-4 inline-flex size-10 items-center justify-center rounded-xl bg-red-100 text-red-600">
                <.icon name="hero-exclamation-triangle" class="size-5" />
              </div>

              <h3 class="text-lg font-semibold text-slate-900">Delete your account?</h3>

              <p class="mt-2 text-sm text-slate-600">
                This action is permanent. You will lose access to all stores and cannot undo this later.
              </p>
            </div>

            <div class="flex items-center justify-end gap-2 border-t border-slate-100 px-6 py-4">
              <button
                type="button"
                phx-click="cancel-delete-modal"
                class="rounded-lg px-3 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100"
              >
                Cancel
              </button>
              <form id="delete-account-confirm-form" phx-submit="delete-account">
                <button
                  type="submit"
                  phx-disable-with="Deleting..."
                  class="inline-flex items-center gap-2 rounded-lg bg-red-600 px-3 py-2 text-sm font-semibold text-white hover:bg-red-700"
                >
                  <.icon name="hero-trash" class="size-4" /> Yes, delete
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </Layouts.shell>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_admin_user_email(socket.assigns.current_scope.admin_user, token) do
        {:ok, _admin_user} ->
          socket

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
      |> assign(:show_delete_modal, false)

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

  def handle_event("open-delete-modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  def handle_event("cancel-delete-modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
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

        {:noreply, socket}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("delete-account", _params, socket) do
    admin_user = socket.assigns.current_scope.admin_user

    case Team.delete_admin_user(admin_user) do
      {:ok, _deleted_user} ->
        {:noreply, redirect(socket, to: ~p"/admin_users/log-in")}

      {:error, :last_admin} ->
        {:noreply,
         socket
         |> assign(:show_delete_modal, false)
         |> put_flash(
           :error,
           "You are the only admin. Promote a non-admin to admin before deleting your account."
         )}
    end
  end
end
