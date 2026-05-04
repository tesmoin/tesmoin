defmodule TesmoinWeb.TeamLive do
  use TesmoinWeb, :live_view

  alias Tesmoin.Team
  alias Tesmoin.Accounts.AdminUser
  alias Tesmoin.Team.MemberInvitation

  def mount(_params, _session, socket) do
    members = Team.list_members()
    pending = Team.list_pending_invitations()
    changeset = Team.change_invitation(%MemberInvitation{})
    current_user = socket.assigns.current_scope.admin_user

    {:ok,
     assign(socket,
       members: members,
       pending_invitations: pending,
       form: to_form(changeset),
       roles: AdminUser.valid_roles(),
       current_user_is_admin: Team.admin_member?(current_user.id),
       show_invite_form: false
     )}
  end

  def handle_event("show-invite-form", _params, %{assigns: %{current_user_is_admin: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("show-invite-form", _params, socket) do
    {:noreply, assign(socket, show_invite_form: true)}
  end

  def handle_event("hide-invite-form", _params, socket) do
    changeset = Team.change_invitation(%MemberInvitation{})
    {:noreply, assign(socket, show_invite_form: false, form: to_form(changeset))}
  end

  def handle_event("validate", %{"member_invitation" => params}, socket) do
    changeset =
      %MemberInvitation{}
      |> Team.change_invitation(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("invite", _params, %{assigns: %{current_user_is_admin: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("invite", %{"member_invitation" => params}, socket) do
    invited_by = socket.assigns.current_scope.admin_user

    case Team.create_invitation(params, invited_by) do
      {:ok, _invitation} ->
        changeset = Team.change_invitation(%MemberInvitation{})
        pending = Team.list_pending_invitations()

        {:noreply,
         socket
         |> assign(
           show_invite_form: false,
           form: to_form(changeset),
           pending_invitations: pending
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("change-role", %{"member_id" => member_id, "role" => role}, socket) do
    current_user = socket.assigns.current_scope.admin_user

    case Integer.parse(member_id) do
      {parsed_member_id, ""} ->
        case Team.change_member_role(current_user, parsed_member_id, role) do
          {:ok, :updated} ->
            {:noreply, assign(socket, :members, Team.list_members())}

          {:error, :admin_not_editable} ->
            {:noreply, put_flash(socket, :error, "Admin roles cannot be edited from Team.")}

          {:error, :forbidden} ->
            {:noreply, put_flash(socket, :error, "Only admins can change member roles.")}

          {:error, :invalid_role} ->
            {:noreply, put_flash(socket, :error, "Invalid role selected.")}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Member not found.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid member.")}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.shell
      flash={@flash}
      current_scope={@current_scope}
      current_tab={:team}
      stores={@stores}
      current_store={@current_store}
    >
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Team</h1>

            <p class="mt-1 text-sm text-slate-500">Manage who has access to this node.</p>
          </div>

          <button
            :if={@current_user_is_admin && !@show_invite_form}
            phx-click="show-invite-form"
            class="backoffice-button-primary inline-flex items-center gap-2 px-4 py-2.5"
          >
            <.icon name="hero-user-plus" class="size-4" /> Invite member
          </button>
        </div>
        <%!-- Invite form --%>
        <div :if={@show_invite_form} class="backoffice-card p-6">
          <h2 class="text-base font-semibold text-slate-800 mb-4">Invite a new member</h2>

          <.form
            for={@form}
            id="invite-form"
            phx-change="validate"
            phx-submit="invite"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email address"
              placeholder="colleague@example.com"
              required
            />
            <.input
              field={@form[:role]}
              type="select"
              label="Role"
              prompt="Select a role..."
              options={Enum.map(MemberInvitation.valid_roles(), &{String.capitalize(&1), &1})}
            />

            <div class="flex gap-3 pt-1">
              <button
                type="button"
                phx-click="hide-invite-form"
                class="backoffice-button-secondary px-4 py-2"
              >
                Cancel
              </button>
              <button type="submit" class="backoffice-button-primary flex-1 py-2">
                Send invitation
              </button>
            </div>
          </.form>
        </div>
        <%!-- Current members --%>
        <div class="backoffice-card overflow-hidden">
          <div class="px-5 py-4 border-b border-slate-100">
            <h2 class="text-base font-semibold text-slate-800">Members</h2>
          </div>

          <ul class="divide-y divide-slate-50">
            <%= for member <- @members do %>
              <li class="flex items-center justify-between gap-4 px-5 py-3">
                <div class="flex items-center gap-3 min-w-0">
                  <div class="flex size-8 shrink-0 items-center justify-center rounded-full bg-[color-mix(in_oklab,var(--tes-primary)_15%,white)] text-xs font-bold text-[--tes-primary] uppercase">
                    {String.at(member.email, 0)}
                  </div>

                  <div class="min-w-0">
                    <p class="text-sm font-medium text-slate-800 truncate">{member.email}</p>

                    <%= if member.store_memberships == [] do %>
                      <p class="text-xs text-slate-400">No store memberships</p>
                    <% else %>
                      <p class="text-xs text-slate-400 truncate">
                        {member.store_memberships
                        |> Enum.map(& &1.store.name)
                        |> Enum.join(", ")}
                      </p>
                    <% end %>
                  </div>
                </div>

                <div class="flex flex-wrap gap-1.5 shrink-0 items-center">
                  <%= if editable_member?(@current_user_is_admin, member) do %>
                    <form
                      phx-change="change-role"
                      phx-submit="change-role"
                      id={"member-role-form-#{member.id}"}
                      class="inline-flex items-center gap-2 rounded-full border border-[color-mix(in_oklab,var(--tes-primary)_22%,white)] bg-white/90 px-1.5 py-1 shadow-sm"
                    >
                      <input type="hidden" name="member_id" value={member.id} />
                      <div class="relative">
                        <select
                          name="role"
                          class="appearance-none rounded-full bg-[color-mix(in_oklab,var(--tes-secondary)_65%,white)] pl-3 pr-8 py-1.5 text-xs font-semibold text-slate-700 border border-transparent focus:border-[--tes-primary] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--tes-primary)_28%,white)]"
                        >
                          <option
                            :for={role <- @roles}
                            value={role}
                            selected={role == member_role(member)}
                          >
                            {String.capitalize(role)}
                          </option>
                        </select>
                        <.icon
                          name="hero-chevron-down"
                          class="pointer-events-none absolute right-2 top-1/2 size-3.5 -translate-y-1/2 text-slate-500"
                        />
                      </div>
                    </form>
                  <% else %>
                    <%= if role = member_role(member) do %>
                      <span class={[
                        "rounded-full px-2 py-0.5 text-xs font-semibold",
                        role_badge_class(role)
                      ]}>
                        {String.capitalize(role)}
                      </span>
                    <% end %>
                  <% end %>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
        <%!-- Pending invitations --%>
        <div :if={@pending_invitations != []} class="backoffice-card overflow-hidden">
          <div class="px-5 py-4 border-b border-slate-100 flex items-center gap-2">
            <h2 class="text-base font-semibold text-slate-800">Pending invitations</h2>

            <span class="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">
              {length(@pending_invitations)}
            </span>
          </div>

          <ul class="divide-y divide-slate-50">
            <%= for inv <- @pending_invitations do %>
              <li class="flex items-center justify-between gap-4 px-5 py-3">
                <div>
                  <p class="text-sm font-medium text-slate-700">{inv.email}</p>

                  <p class="text-xs text-slate-400">
                    Invited by {inv.invited_by && inv.invited_by.email} -
                    expires {Calendar.strftime(inv.expires_at, "%b %-d, %Y")}
                  </p>
                </div>

                <span class={[
                  "rounded-full px-2 py-0.5 text-xs font-semibold",
                  role_badge_class(inv.role)
                ]}>
                  {String.capitalize(inv.role)}
                </span>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </Layouts.shell>
    """
  end

  defp member_role(member), do: member.role

  defp editable_member?(false, _member), do: false
  defp editable_member?(true, member), do: member_role(member) not in [nil, "admin"]

  defp role_badge_class("admin"), do: "bg-violet-100 text-violet-700"
  defp role_badge_class("editor"), do: "bg-blue-100 text-blue-700"
  defp role_badge_class("moderator"), do: "bg-emerald-100 text-emerald-700"
  defp role_badge_class(_), do: "bg-slate-100 text-slate-600"
end
