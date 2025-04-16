defmodule HeadsUpWeb.Admin.DashboardLive do
  use HeadsUpWeb, :live_view

  # Ensure admin access
  on_mount {HeadsUpWeb.Plugs.EnsureAdmin, :ensure_admin}

  @impl true
  def mount(_params, _session, socket) do
    # UserAuth now assigns current_user directly, so we can use it without extraction
    {:ok, assign(socket, 
      page_title: "Admin Dashboard",
      metrics: %{
        total_users: 0,  # Placeholder - will be implemented later
        active_sessions: 0,  # Placeholder - will be implemented later
        system_status: "Operational"  # Placeholder - will be implemented later
      }
    )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold">Admin Dashboard</h1>
        <p class="text-gray-500">Welcome to the administrative interface</p>
      </div>
      
      <div class="bg-red-100 dark:bg-red-900 border-l-4 border-red-500 text-red-700 dark:text-red-300 p-4 mb-6" role="alert">
        <p class="font-bold">Admin Only Area</p>
        <p>This dashboard is only accessible to administrators.</p>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-base-200 rounded-lg shadow-md p-6">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="text-lg font-semibold mb-2">Total Users</h3>
              <p class="text-3xl font-bold"><%= @metrics.total_users %></p>
            </div>
            <div class="rounded-full bg-base-300 p-3">
              <.icon name="hero-users" class="size-6" />
            </div>
          </div>
        </div>
        
        <div class="bg-base-200 rounded-lg shadow-md p-6">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="text-lg font-semibold mb-2">Active Sessions</h3>
              <p class="text-3xl font-bold"><%= @metrics.active_sessions %></p>
            </div>
            <div class="rounded-full bg-base-300 p-3">
              <.icon name="hero-signal" class="size-6" />
            </div>
          </div>
        </div>
        
        <div class="bg-base-200 rounded-lg shadow-md p-6">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="text-lg font-semibold mb-2">System Status</h3>
              <p class="text-3xl font-bold"><%= @metrics.system_status %></p>
            </div>
            <div class="rounded-full bg-base-300 p-3">
              <.icon name="hero-server" class="size-6" />
            </div>
          </div>
        </div>
      </div>
      
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-base-200 rounded-lg shadow-md p-6">
          <h2 class="text-xl font-semibold mb-4">Management Tools</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <button class="btn btn-primary">Manage Users</button>
            <button class="btn btn-primary">System Settings</button>
            <button class="btn btn-primary">Activity Logs</button>
            <button class="btn btn-primary">Send Notifications</button>
          </div>
        </div>
        
        <div class="bg-base-200 rounded-lg shadow-md p-6">
          <h2 class="text-xl font-semibold mb-4">Recent Activity</h2>
          <div class="border rounded-lg divide-y">
            <div class="p-3 flex items-center">
              <.icon name="hero-user-circle" class="mr-3 size-5" />
              <span>No recent activity to display</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

