defmodule HeadsUpWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use HeadsUpWeb, :html

  embed_templates "layouts/*"

  @doc """
  The app layout that wraps all pages.
  
  ## Attributes
  
  * `current_user` - The current authenticated user (optional)
  """
  attr :current_user, :map, default: nil
  
  def app(assigns) do
    ~H"""
    <header class="bg-base-100 shadow-sm">
      <div class="container mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <!-- Left side - Logo/Brand -->
          <div class="flex items-center">
            <a href="/" class="flex items-center gap-2">
              <img src={~p"/images/logo.svg"} width="36" alt="Heads Up Logo" />
              <span class="text-lg font-semibold">Heads Up</span>
            </a>
          </div>
          
          <!-- Right side - Navigation -->
          <div class="flex items-center space-x-4">
            <!-- Main Navigation -->
            <nav class="flex items-center space-x-2">
              <a href="/" class="btn btn-ghost btn-sm">Home</a>
              
              <%= if @current_user && @current_user.is_admin do %>
                <a href="/admin/dashboard" class="btn btn-ghost btn-sm">
                  Dashboard
                </a>
              <% end %>
            </nav>
            
            <!-- Theme toggle -->
            <div class="mr-2">
              <.theme_toggle />
            </div>
            
            <!-- User account navigation -->
            <div class="flex items-center">
              <%= if @current_user do %>
                <div class="dropdown dropdown-end">
                  <label tabindex="0" class="btn btn-ghost btn-sm">
                    <%= @current_user.email |> String.split("@") |> hd() %>
                    <.icon name="hero-chevron-down-micro" class="ml-1 size-4" />
                  </label>
                  <ul tabindex="0" class="dropdown-content z-10 menu p-2 shadow bg-base-100 rounded-box w-52">
                    <li>
                      <a href={~p"/users/settings"}>Settings</a>
                    </li>
                    <li>
                      <.link href={~p"/users/log-out"} method="delete">
                        Logout
                      </.link>
                    </li>
                  </ul>
                </div>
              <% else %>
                <a href={~p"/users/log-in"} class="btn btn-primary btn-sm">
                  Login <span aria-hidden="true">&rarr;</span>
                </a>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Hang in there while we get back on track")}
        <.icon name="hero-arrow-path" class="ml-1 h-3 w-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-[33%] h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-[33%] [[data-theme=dark]_&]:left-[66%] transition-[left]" />

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})} class="flex p-2">
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})} class="flex p-2">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})} class="flex p-2">
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
