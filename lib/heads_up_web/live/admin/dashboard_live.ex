defmodule HeadsUpWeb.Admin.DashboardLive do
  use HeadsUpWeb, :live_view
  alias HeadsUp.Accounts

  # Ensure admin access
  on_mount {HeadsUpWeb.Plugs.EnsureAdmin, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    # Get user statistics
    stats = Accounts.get_user_stats()

    # Get recent users
    recent_users = Accounts.list_recent_users(5)

    # Initialize search and pagination
    pagination_opts = %{page: 1, per_page: 10}
    filter_opts = %{}

    # Get paginated users
    {users, pagination} = Accounts.list_users(Map.merge(pagination_opts, %{filter: filter_opts}))

    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign(:metrics, %{
          total_users: stats.total_users,
          active_users: stats.active_users,
          admin_users: stats.admin_users,
          unconfirmed_users: stats.unconfirmed_users,
          system_status: "Operational"
        })
      |> assign(:users, users)
      |> assign(:recent_users, recent_users)
      |> assign(:pagination, pagination)
      |> assign(:search_term, "")
      |> assign(:filter_opts, filter_opts)
      |> assign(:show_user_modal, false)
      |> assign(:selected_user, nil)
      |> assign(:user_activity, nil)
      |> assign(:selected_tab, "overview")
      |> assign(:filter_admin, nil)
      |> assign(:filter_confirmed, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = String.to_integer(params["page"] || "1")
    search = params["search"]
    admin_filter = params["admin"]
    confirmed_filter = params["confirmed"]
    selected_tab = params["tab"] || socket.assigns.selected_tab

    filter_opts = %{}

    # Apply search filter if provided
    filter_opts = if search && search != "",
      do: Map.put(filter_opts, :search, search),
      else: filter_opts

    # Apply admin filter if provided
    filter_opts = case admin_filter do
      "true" -> Map.put(filter_opts, :is_admin, true)
      "false" -> Map.put(filter_opts, :is_admin, false)
      _ -> filter_opts
    end

    # Apply confirmed filter if provided
    filter_opts = case confirmed_filter do
      "true" -> Map.put(filter_opts, :confirmed, true)
      "false" -> Map.put(filter_opts, :confirmed, false)
      _ -> filter_opts
    end

    # Get paginated users with filters if on users tab
    {users, pagination} =
      if selected_tab == "users" do
        Accounts.list_users(%{
          page: page,
          per_page: 10,
          filter: filter_opts
        })
      else
        {socket.assigns.users, socket.assigns.pagination}
      end

    socket =
      socket
      |> assign(:selected_tab, selected_tab)
      |> assign(:users, users)
      |> assign(:pagination, pagination)
      |> assign(:search_term, search || "")
      |> assign(:filter_opts, filter_opts)
      |> assign(:filter_admin, admin_filter)
      |> assign(:filter_confirmed, confirmed_filter)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_admin", %{"id" => user_id}, socket) do
    with %{users: users} <- socket.assigns,
         user when not is_nil(user) <- Enum.find(users, fn u -> "#{u.id}" == user_id end) do

      case Accounts.set_admin_status(user, !user.is_admin) do
        {:ok, updated_user} ->
          # Update the user in the list
          updated_users =
            Enum.map(users, fn u ->
              if u.id == updated_user.id, do: updated_user, else: u
            end)

          # Get updated stats
          stats = Accounts.get_user_stats()

          socket =
            socket
            |> assign(:users, updated_users)
            |> assign(:metrics, %{socket.assigns.metrics | admin_users: stats.admin_users})
            |> put_flash(:info, "User admin status updated successfully")

          {:noreply, socket}

        {:error, _changeset} ->
          socket = socket |> put_flash(:error, "Failed to update user admin status")
          {:noreply, socket}
      end
    else
      _ ->
        socket = socket |> put_flash(:error, "User not found")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"search" => %{"term" => search_term}}, socket) do
    # Build the params map for navigation
    params = %{"page" => "1", "tab" => "users"}
    params = if search_term != "", do: Map.put(params, "search", search_term), else: params
    params = if socket.assigns.filter_admin, do: Map.put(params, "admin", socket.assigns.filter_admin), else: params
    params = if socket.assigns.filter_confirmed, do: Map.put(params, "confirmed", socket.assigns.filter_confirmed), else: params

    # Navigate to apply search
    {:noreply, push_patch(socket, to: ~p"/admin/dashboard?#{params}")}
  end

  @impl true
  def handle_event("filter_admin", %{"value" => value}, socket) do
    # Build the params map for navigation
    params = %{"page" => "1", "admin" => value, "tab" => "users"}
    params = if socket.assigns.search_term != "", do: Map.put(params, "search", socket.assigns.search_term), else: params
    params = if socket.assigns.filter_confirmed, do: Map.put(params, "confirmed", socket.assigns.filter_confirmed), else: params

    # Navigate to apply filter
    {:noreply, push_patch(socket, to: ~p"/admin/dashboard?#{params}")}
  end

  @impl true
  def handle_event("filter_confirmed", %{"value" => value}, socket) do
    # Build the params map for navigation
    params = %{"page" => "1", "confirmed" => value, "tab" => "users"}
    params = if socket.assigns.search_term != "", do: Map.put(params, "search", socket.assigns.search_term), else: params
    params = if socket.assigns.filter_admin, do: Map.put(params, "admin", socket.assigns.filter_admin), else: params

    # Navigate to apply filter
    {:noreply, push_patch(socket, to: ~p"/admin/dashboard?#{params}")}
  end

  @impl true
  def handle_event("show_user", %{"id" => user_id}, socket) do
    with %{users: users} <- socket.assigns,
         user when not is_nil(user) <- Enum.find(users, fn u -> "#{u.id}" == user_id end) do

      # Get user activity data
      activity = Accounts.get_user_activity(user)

      {:noreply, assign(socket, show_user_modal: true, selected_user: user, user_activity: activity)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "User not found")}
    end
  end

  @impl true
  def handle_event("close_user_modal", _, socket) do
    {:noreply, assign(socket, show_user_modal: false, selected_user: nil, user_activity: nil)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/dashboard?#{%{tab: tab}}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold">Admin Dashboard</h1>
        <p class="text-gray-500">Welcome to the administrative interface</p>
      </div>

      <div class="tabs tabs-boxed mb-6">
        <a class={["tab", @selected_tab == "overview" && "tab-active"]} phx-click="change_tab" phx-value-tab="overview">
          Overview
        </a>
        <a class={["tab", @selected_tab == "users" && "tab-active"]} phx-click="change_tab" phx-value-tab="users">
          Users Management
        </a>
        <a class={["tab", @selected_tab == "settings" && "tab-active"]} phx-click="change_tab" phx-value-tab="settings">
          System Settings
        </a>
      </div>

      <%= if @selected_tab == "overview" do %>
        <.dashboard_overview metrics={@metrics} recent_users={@recent_users} />
      <% end %>

      <%= if @selected_tab == "users" do %>
        <.user_management
          users={@users}
          pagination={@pagination}
          search_term={@search_term}
          filter_admin={@filter_admin}
          filter_confirmed={@filter_confirmed}
        />
      <% end %>

      <%= if @selected_tab == "settings" do %>
        <.system_settings />
      <% end %>

      <%= if @show_user_modal do %>
        <.user_details_modal user={@selected_user} activity={@user_activity} />
      <% end %>
    </div>
    """
  end

  def dashboard_overview(assigns) do
    ~H"""
    <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
      <div class="stats shadow">
        <div class="stat">
          <div class="stat-title">Total Users</div>
          <div class="stat-value"><%= @metrics.total_users %></div>
          <div class="stat-desc">Registered accounts</div>
        </div>
      </div>

      <div class="stats shadow">
        <div class="stat">
          <div class="stat-title">Active Users</div>
          <div class="stat-value"><%= @metrics.active_users %></div>
          <div class="stat-desc">Last 30 days</div>
        </div>
      </div>

      <div class="stats shadow">
        <div class="stat">
          <div class="stat-title">Admin Users</div>
          <div class="stat-value"><%= @metrics.admin_users %></div>
          <div class="stat-desc">With elevated access</div>
        </div>
      </div>

      <div class="stats shadow">
        <div class="stat">
          <div class="stat-title">System Status</div>
          <div class="stat-value text-success"><%= @metrics.system_status %></div>
          <div class="stat-desc">All systems normal</div>
        </div>
      </div>
    </div>

    <div class="mt-8">
      <h2 class="text-xl font-semibold mb-4">Recent Users</h2>
      <div class="overflow-x-auto">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Email</th>
              <th>Status</th>
              <th>Registered</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= for user <- @recent_users do %>
              <tr>
                <td><%= user.email %></td>
                <td>
                  <%= cond do %>
                    <% user.is_admin -> %>
                      <span class="badge badge-primary">Admin</span>
                    <% is_nil(user.confirmed_at) -> %>
                      <span class="badge badge-warning">Unconfirmed</span>
                    <% true -> %>
                      <span class="badge badge-success">Active</span>
                  <% end %>
                </td>
                <td><%= Calendar.strftime(user.inserted_at, "%Y-%m-%d %H:%M") %></td>
                <td>
                  <button class="btn btn-sm btn-ghost" phx-click="show_user" phx-value-id={user.id}>
                    View Details
                  </button>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  def user_management(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex gap-4 items-center">
        <div class="flex-1">
          <.form :let={_f} for={%{}} as={:search} phx-submit="search" class="w-full">
            <div class="input-group w-full">
              <input
                type="text"
                name={"search[term]"}
                value={@search_term}
                placeholder="Search users..."
                class="input input-bordered w-full"
              />
              <button type="submit" class="btn btn-square">
                <.icon name="hero-magnifying-glass" class="size-5" />
              </button>
            </div>
          </.form>
        </div>

        <div class="join">
          <button
            class={["btn btn-sm join-item", is_nil(@filter_admin) && "btn-active"]}
            phx-click="filter_admin"
            phx-value-value=""
          >
            All
          </button>
          <button
            class={["btn btn-sm join-item", @filter_admin == "true" && "btn-active"]}
            phx-click="filter_admin"
            phx-value-value="true"
          >
            Admins
          </button>
          <button
            class={["btn btn-sm join-item", @filter_admin == "false" && "btn-active"]}
            phx-click="filter_admin"
            phx-value-value="false"
          >
            Regular
          </button>
        </div>

        <div class="join">
          <button
            class={["btn btn-sm join-item", is_nil(@filter_confirmed) && "btn-active"]}
            phx-click="filter_confirmed"
            phx-value-value=""
          >
            All
          </button>
          <button
            class={["btn btn-sm join-item", @filter_confirmed == "true" && "btn-active"]}
            phx-click="filter_confirmed"
            phx-value-value="true"
          >
            Confirmed
          </button>
          <button
            class={["btn btn-sm join-item", @filter_confirmed == "false" && "btn-active"]}
            phx-click="filter_confirmed"
            phx-value-value="false"
          >
            Unconfirmed
          </button>
        </div>
      </div>

      <div class="overflow-x-auto">
        <table class="table table-zebra w-full">
          <thead>
            <tr>
              <th>Email</th>
              <th>Status</th>
              <th>Registered</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <%= if length(@users) > 0 do %>
              <%= for user <- @users do %>
                <tr>
                  <td><%= user.email %></td>
                  <td>
                    <%= cond do %>
                      <% user.is_admin -> %>
                        <span class="badge badge-primary">Admin</span>
                      <% is_nil(user.confirmed_at) -> %>
                        <span class="badge badge-warning">Unconfirmed</span>
                      <% true -> %>
                        <span class="badge badge-success">Active</span>
                    <% end %>
                  </td>
                  <td><%= Calendar.strftime(user.inserted_at, "%Y-%m-%d %H:%M") %></td>
                  <td>
                    <div class="flex gap-2">
                      <button class="btn btn-sm btn-ghost" phx-click="toggle_admin" phx-value-id={user.id}>
                        <%= if user.is_admin, do: "Remove Admin", else: "Make Admin" %>
                      </button>
                      <button class="btn btn-sm btn-ghost" phx-click="show_user" phx-value-id={user.id}>
                        View Details
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            <% else %>
              <tr>
                <td colspan="4" class="text-center py-4">
                  <div class="flex flex-col items-center justify-center">
                    <.icon name="hero-user-slash" class="size-8 mb-2 opacity-60" />
                    <span>No users found</span>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="flex items-center justify-between">
        <div class="text-sm text-gray-600">
          Showing <%= length(@users) %> of <%= @pagination.total_count %> users
        </div>

        <div class="join">
          <%= for page <- 1..@pagination.total_pages do %>
            <.link
              patch={~p"/admin/dashboard?#{%{page: page, tab: "users", search: @search_term, admin: @filter_admin, confirmed: @filter_confirmed}}"}
              class={["join-item btn btn-sm", page == @pagination.page && "btn-active"]}
            >
              <%= page %>
            </.link>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def system_settings(assigns) do
    ~H"""
    <div class="grid gap-6 md:grid-cols-2">
      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h3 class="card-title">Email Settings</h3>
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text">SMTP Host</span>
            </label>
            <input type="text" value="smtp.example.com" class="input input-bordered" disabled />
          </div>
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text">SMTP Port</span>
            </label>
            <input type="number" value="587" class="input input-bordered" disabled />
          </div>
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text">Sender Email</span>
            </label>
            <input type="email" value="noreply@example.com" class="input input-bordered" disabled />
          </div>
          <div class="card-actions justify-end">
            <button class="btn btn-primary" disabled>Save Settings</button>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h3 class="card-title">Security Settings</h3>
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text">Session Timeout (minutes)</span>
            </label>
            <input type="number" value="120" class="input input-bordered" disabled />
          </div>
          <div class="form-control mb-4">
            <label class="label">
              <span class="label-text">Password Requirements</span>
            </label>
            <select class="select select-bordered" disabled>
              <option>Standard (8+ characters)</option>
              <option selected>Strong (12+ characters)</option>
              <option>Very Strong (16+ chars with special characters)</option>
            </select>
          </div>
          <div class="card-actions justify-end">
            <button class="btn btn-primary" disabled>Save Settings</button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def user_details_modal(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">User Details</h3>

        <div class="space-y-4">
          <div>
            <label class="text-sm font-medium">Email</label>
            <p class="text-lg"><%= @user.email %></p>
          </div>

          <div>
            <label class="text-sm font-medium">Status</label>
            <div class="flex gap-2 mt-1">
              <%= if @user.is_admin do %>
                <span class="badge badge-primary">Admin</span>
              <% end %>
              <%= if @user.confirmed_at do %>
                <span class="badge badge-success">Confirmed</span>
              <% else %>
                <span class="badge badge-warning">Unconfirmed</span>
              <% end %>
            </div>
          </div>

          <div>
            <label class="text-sm font-medium">Activity</label>
            <dl class="mt-1 space-y-1 text-sm">
              <div class="flex justify-between">
                <dt>Registered:</dt>
                <dd><%= Calendar.strftime(@user.inserted_at, "%Y-%m-%d %H:%M") %></dd>
              </div>
              <%= if @activity.last_login do %>
                <div class="flex justify-between">
                  <dt>Last login:</dt>
                  <dd><%= Calendar.strftime(@activity.last_login, "%Y-%m-%d %H:%M") %></dd>
                </div>
              <% end %>
              <div class="flex justify-between">
                <dt>Login count:</dt>
                <dd><%= @activity.login_count %></dd>
              </div>
            </dl>
          </div>
        </div>

        <div class="modal-action">
          <button class="btn" phx-click="close_user_modal">Close</button>
        </div>
      </div>
    </div>
    """
  end
end
