defmodule TesmoinWeb.TeamLive do
  use TesmoinWeb, :live_view

  alias Tesmoin.Stores
  alias Tesmoin.Team
  alias Tesmoin.Team.MemberInvitation

  def mount(_params, _session, socket) do
    stores = Stores.list_stores()
    members = Team.list_members()
    pending = Team.list_pending_invitations()
    changeset = Team.change_invitation(%MemberInvitation{})

    {:ok,
     assign(socket,
       stores: stores,
       members: members,
       pending_invitations: pending,
       form: to_form(changeset),
       show_invite_form: false
     )}
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

  def handle_event("invite", %{"member_invitation" => params}, socket) do
    invited_by = socket.assigns.current_scope.admin_user

    case Team.create_invitation(params, invited_by) do
      {:ok, _invitation} ->
        changeset = Team.change_invitation(%MemberInvitation{})
        pending = Team.list_pending_invitations()

        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent successfully.")
         |> assign(
           show_invite_form: false,
           form: to_form(changeset),
           pending_invitations: pending
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.shell flash={@flash} current_scope={@current_scope} current_tab={:team}>
      <div class="space-y-6">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-slate-800">Team</h1>
            <p class="mt-1 text-sm text-slate-500">Manage who has access to this node.</p>
          </div>
          <button
            :if={!@show_invite_form}
            phx-click="show-invite-form"
            class="backoffice-button-primary inline-flex items-center gap-2 px-4 py-2.5"
          >
            <.icon name="hero-user-plus" class="size-4" />
            Invite member
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

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Role</label>
              <select
                name="member_invitation[role]"
                id="member_invitation_role"
                class="w-full rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm text-slate-800 shadow-sm focus:border-[--tes-primary] focus:outline-none focus:ring-2 focus:ring-[color-mix(in_oklab,var(--tes-primary)_30%,white)]"
              >
                <option value="">Select a role…</option>
                <option
                  :for={role <- MemberInvitation.valid_roles()}
                  value={role}
                  selected={@form[:role].value == role}
                >
                  {String.capitalize(role)}
                </option>
              </select>
              <%= if @form[:role].errors != [] do %>
                <p class="mt-1 text-xs text-red-500">
                  {elem(hd(@form[:role].errors), 0) |> Phoenix.Naming.humanize()}
                </p>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-slate-700 mb-2">
                Stores
                <span class="text-slate-400 font-normal ml-1">— select one or more</span>
              </label>
              <%= if @stores == [] do %>
                <p class="text-sm text-amber-600 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
                  No stores yet. <.link navigate={~p"/stores/new"} class="font-semibold underline">Add a store</.link> first.
                </p>
              <% else %>
                <div class="space-y-2 rounded-xl border border-slate-200 bg-slate-50 p-3">
                  <%= for store <- @stores do %>
                    <label class="flex items-center gap-3 cursor-pointer group">
                      <input
                        type="checkbox"
                        name="member_invitation[store_ids][]"
                        value={store.id}
                        checked={store.id in (Phoenix.HTML.Form.input_value(@form, :store_ids) || [])}
                        class="size-4 rounded border-slate-300 accent-[--tes-primary]"
                      />
                      <span class="text-sm text-slate-700 group-hover:text-slate-900">
                        {store.name}
                        <span class="text-slate-400 text-xs ml-1">/{store.slug}</span>
                      </span>
                    </label>
                  <% end %>
                </div>
              <% end %>
              <%= if @form[:store_ids].errors != [] do %>
                <p class="mt-1 text-xs text-red-500">
                  {elem(hd(@form[:store_ids].errors), 0) |> Phoenix.Naming.humanize()}
                </p>
              <% end %>
            </div>

            <div class="flex gap-3 pt-1">
              <button type="button" phx-click="hide-invite-form" class="backoffice-button-secondary px-4 py-2">
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
                <div class="flex flex-wrap gap-1.5 shrink-0">
                  <%= for membership <- member.store_memberships do %>
                    <span class={[
                      "rounded-full px-2 py-0.5 text-xs font-semibold",
                      role_badge_class(membership.role)
                    ]}>
                      {String.capitalize(membership.role)}
                    </span>
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
                    Invited by {inv.invited_by && inv.invited_by.email} ·
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

  defp role_badge_class("admin"), do: "bg-violet-100 text-violet-700"
  defp role_badge_class("editor"), do: "bg-blue-100 text-blue-700"
  defp role_badge_class("moderator"), do: "bg-emerald-100 text-emerald-700"
  defp role_badge_class(_), do: "bg-slate-100 text-slate-600"
end
