defmodule HeadsUpWeb.HomeLive do
  use HeadsUpWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold mb-4">Welcome to Heads Up</h1>
        <p class="text-lg text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
          Your centralized monitoring and notification platform
        </p>
      </div>

      <%= if @current_user do %>
        <!-- Authenticated User View -->
        <div class="bg-base-200 rounded-lg shadow-md p-6 mb-8">
          <div class="flex items-center gap-4 mb-4">
            <div class="rounded-full bg-primary p-3">
              <.icon name="hero-user-circle" class="size-6 text-white" />
            </div>
            <div>
              <h2 class="text-xl font-semibold">Welcome back, <%= String.split(@current_user.email, "@") |> hd() %></h2>
              <p class="text-sm text-gray-500">Logged in as <%= @current_user.email %></p>
            </div>
          </div>
          
          <div class="bg-base-100 rounded-lg shadow-sm p-4 mt-4 mb-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <div class="rounded-full bg-green-100 p-2">
                  <.icon name="hero-check-circle" class="size-5 text-green-500" />
                </div>
                <span class="font-medium">System Status:</span>
                <span class="text-green-600 font-semibold">Operational</span>
              </div>
              <span class="text-xs text-gray-500">Last updated: Just now</span>
            </div>
          </div>
          
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-6">
            <div class="card bg-base-100 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-lg">My Settings</h3>
                <p>Update your account and notification preferences</p>
                <div class="card-actions justify-end mt-4">
                  <.link navigate={~p"/users/settings"} class="btn btn-primary btn-sm">
                    Settings
                  </.link>
                </div>
              </div>
            </div>
            
            <%= if @current_user.is_admin do %>
              <div class="card bg-base-100 shadow-sm">
                <div class="card-body">
                  <h3 class="card-title text-lg">Admin Dashboard</h3>
                  <p>View and manage system settings</p>
                  <div class="card-actions justify-end mt-4">
                    <.link navigate={~p"/admin/dashboard"} class="btn btn-primary btn-sm">
                      Dashboard
                    </.link>
                  </div>
                </div>
              </div>
            <% end %>
            
            <div class="card bg-base-100 shadow-sm">
              <div class="card-body">
                <h3 class="card-title text-lg">Notifications</h3>
                <p>View your recent notifications</p>
                <div class="card-actions justify-end mt-4">
                  <button class="btn btn-primary btn-sm btn-disabled">
                    Coming Soon
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Non-Authenticated User View -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mb-12">
          <div class="bg-base-200 rounded-lg shadow-md p-6">
            <h2 class="text-2xl font-bold mb-4">Get Started</h2>
            <p class="mb-4">Create an account to access all features and receive customized notifications.</p>
            <div class="flex gap-4 mt-6">
              <.link navigate={~p"/users/log-in"} class="btn btn-primary">
                Login
              </.link>
              <.link navigate={~p"/users/register"} class="btn btn-outline">
                Register
              </.link>
            </div>
          </div>
          
          <div class="bg-base-200 rounded-lg shadow-md p-6">
            <h2 class="text-2xl font-bold mb-4">Key Features</h2>
            <ul class="space-y-2">
              <li class="flex items-center gap-2">
                <.icon name="hero-check-circle" class="size-5 text-green-500" />
                <span>Real-time monitoring and alerts</span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-check-circle" class="size-5 text-green-500" />
                <span>Customizable notification preferences</span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-check-circle" class="size-5 text-green-500" />
                <span>Admin dashboard for system oversight</span>
              </li>
              <li class="flex items-center gap-2">
                <.icon name="hero-check-circle" class="size-5 text-green-500" />
                <span>Secure authentication system</span>
              </li>
            </ul>
          </div>
        </div>
      <% end %>
      
      <div class="bg-base-200 rounded-lg shadow-md p-6">
        <h2 class="text-2xl font-bold mb-4">About Heads Up</h2>
        <p class="mb-4">
          Heads Up is a comprehensive monitoring and notification platform designed to keep you informed about critical events and system status in real-time.
        </p>
        <p>
          With customizable alerts, detailed dashboards, and robust admin capabilities, Heads Up provides everything you need to stay on top of your systems.
        </p>
      </div>
    </div>
    """
  end
end

