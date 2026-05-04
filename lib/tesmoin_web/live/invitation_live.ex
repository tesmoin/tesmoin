defmodule TesmoinWeb.InvitationLive do
  use TesmoinWeb, :live_view

  alias Tesmoin.Team
  alias Tesmoin.RateLimiter

  def mount(%{"token" => token}, _session, socket) do
    invitation = Team.get_invitation_by_token(token)

    client_ip =
      case get_connect_info(socket, :peer_data) do
        %{address: ip} -> ip
        _ -> nil
      end

    cond do
      is_nil(invitation) ->
        {:ok, assign(socket, state: :invalid, invitation: nil, client_ip: client_ip)}

      not is_nil(invitation.accepted_at) ->
        {:ok,
         assign(socket, state: :already_accepted, invitation: invitation, client_ip: client_ip)}

      DateTime.compare(invitation.expires_at, DateTime.utc_now(:second)) == :lt ->
        {:ok, assign(socket, state: :expired, invitation: invitation, client_ip: client_ip)}

      true ->
        {:ok, assign(socket, state: :pending, invitation: invitation, client_ip: client_ip)}
    end
  end

  def handle_event("accept", _params, %{assigns: %{state: :pending}} = socket) do
    invitation = socket.assigns.invitation
    client_ip = socket.assigns.client_ip

    case RateLimiter.check_magic_link_request(client_ip) do
      :rate_limited ->
        {:noreply,
         put_flash(socket, :error, "Too many requests. Please wait a minute and try again.")}

      _ ->
        case Team.accept_invitation(invitation) do
          {:ok, admin_user} ->
            {:ok, _job} =
              %{admin_user_id: admin_user.id}
              |> Tesmoin.Workers.MagicLinkMailer.new()
              |> Oban.insert()

            {:noreply, assign(socket, state: :accepted)}

          {:error, :already_accepted} ->
            {:noreply, assign(socket, state: :already_accepted)}

          {:error, :expired} ->
            {:noreply, assign(socket, state: :expired)}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} hide_public_auth_action={true}>
      <div class="mx-auto max-w-md">
        <%= case @state do %>
          <% :pending -> %>
            <div class="backoffice-card flex flex-col items-center gap-6 px-8 py-12 text-center">
              <div class="flex size-16 items-center justify-center rounded-2xl bg-[color-mix(in_oklab,var(--tes-secondary)_80%,white)] border border-[color-mix(in_oklab,var(--tes-primary)_18%,white)]">
                <.icon name="hero-envelope-open" class="size-8 text-[--tes-primary]" />
              </div>

              <div>
                <h1 class="text-xl font-bold text-slate-800">You've been invited</h1>

                <p class="mt-2 text-sm text-slate-500 leading-relaxed">
                  {if @invitation.invited_by,
                    do: @invitation.invited_by.email,
                    else: "A Tesmoin administrator"} has invited you to join this Tesmoin node as <span class="font-semibold text-slate-700">{String.capitalize(@invitation.role)}</span>.
                </p>

                <p class="mt-1 text-xs text-slate-400">
                  Invitation for <span class="font-medium">{@invitation.email}</span>
                </p>
              </div>

              <button
                phx-click="accept"
                class="backoffice-button-primary w-full py-3 text-base"
              >
                Accept invitation
              </button>
              <p class="text-xs text-slate-400">
                A sign-in link will be sent to {@invitation.email} after you accept.
              </p>
            </div>
          <% :accepted -> %>
            <div class="backoffice-card flex flex-col items-center gap-6 px-8 py-12 text-center">
              <div class="flex size-16 items-center justify-center rounded-2xl bg-emerald-50 border border-emerald-200">
                <.icon name="hero-check-circle" class="size-8 text-emerald-500" />
              </div>

              <div>
                <h1 class="text-xl font-bold text-slate-800">Invitation accepted!</h1>

                <p class="mt-2 text-sm text-slate-500 leading-relaxed">
                  We've sent a sign-in link to <span class="font-medium">{@invitation.email}</span>.
                  Check your inbox and click the link to access your account.
                </p>
              </div>
            </div>
          <% :already_accepted -> %>
            <div class="backoffice-card flex flex-col items-center gap-6 px-8 py-12 text-center">
              <div class="flex size-16 items-center justify-center rounded-2xl bg-slate-100 border border-slate-200">
                <.icon name="hero-check-circle" class="size-8 text-slate-400" />
              </div>

              <div>
                <h1 class="text-xl font-bold text-slate-800">Already accepted</h1>

                <p class="mt-2 text-sm text-slate-500">
                  This invitation has already been used. You can log in directly.
                </p>
              </div>

              <.link navigate={~p"/admin_users/log-in"} class="backoffice-button-primary px-6 py-2.5">
                Go to login
              </.link>
            </div>
          <% :expired -> %>
            <div class="backoffice-card flex flex-col items-center gap-6 px-8 py-12 text-center">
              <div class="flex size-16 items-center justify-center rounded-2xl bg-red-50 border border-red-200">
                <.icon name="hero-clock" class="size-8 text-red-400" />
              </div>

              <div>
                <h1 class="text-xl font-bold text-slate-800">Invitation expired</h1>

                <p class="mt-2 text-sm text-slate-500">
                  This invitation link has expired. Ask the node owner to send a new one.
                </p>
              </div>
            </div>
          <% :invalid -> %>
            <div class="backoffice-card flex flex-col items-center gap-6 px-8 py-12 text-center">
              <div class="flex size-16 items-center justify-center rounded-2xl bg-red-50 border border-red-200">
                <.icon name="hero-x-circle" class="size-8 text-red-400" />
              </div>

              <div>
                <h1 class="text-xl font-bold text-slate-800">Invalid invitation</h1>

                <p class="mt-2 text-sm text-slate-500">
                  This invitation link is invalid or has been revoked.
                </p>
              </div>
            </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
