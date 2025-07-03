defmodule HeadsUpWeb.EditorLive.Dashboard do
  use HeadsUpWeb, :live_view

  alias HeadsUp.Surveys

  on_mount {HeadsUpWeb.UserAuth, :require_editor}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:user_role, get_user_role(current_user))
     |> assign(:token_stats, Surveys.get_user_token_stats(current_user))
     |> assign(:recent_tokens, Surveys.list_survey_tokens_by_user(current_user) |> Enum.take(10))
     |> assign(:search_term, "")
     |> assign(:filtered_tokens, [])}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    current_user = socket.assigns.current_scope.user
    all_tokens = Surveys.list_survey_tokens_by_user(current_user)

    filtered_tokens =
      if String.trim(search_term) == "" do
        []
      else
        filter_tokens(all_tokens, String.downcase(search_term))
      end

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:filtered_tokens, filtered_tokens)}
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    current_user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(:token_stats, Surveys.get_user_token_stats(current_user))
     |> assign(:recent_tokens, Surveys.list_survey_tokens_by_user(current_user) |> Enum.take(10))}
  end

  defp get_user_role(user) do
    cond do
      user.is_admin -> "Administrator"
      user.is_editor -> "Editor"
      true -> "User"
    end
  end

  defp filter_tokens(tokens, search_term) do
    Enum.filter(tokens, fn token ->
      String.contains?(String.downcase(token.ic_number), search_term) or
        String.contains?(String.downcase(token.token), search_term) or
        (token.birth_place_code &&
           String.contains?(String.downcase(token.birth_place_code), search_term))
    end)
  end

  defp format_datetime(datetime) do
    case datetime do
      nil -> "-"
      dt -> Calendar.strftime(dt, "%Y-%m-%d %H:%M")
    end
  end

  defp token_status(token) do
    cond do
      token.used_at -> :used
      DateTime.compare(DateTime.utc_now(), token.expires_at) == :gt -> :expired
      true -> :active
    end
  end

  defp status_class(:used), do: "bg-purple-100 text-purple-800"
  defp status_class(:expired), do: "bg-gray-100 text-gray-800"
  defp status_class(:active), do: "bg-green-100 text-green-800"

  defp status_text(:used), do: "Used"
  defp status_text(:expired), do: "Expired"
  defp status_text(:active), do: "Active"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto p-6 space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Editor Dashboard</h1>
          <p class="text-gray-600">Welcome back, {@current_user.email} ({@user_role})</p>
        </div>
        <div class="flex space-x-3">
          <.link
            navigate={~p"/token"}
            class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            Generate New Token
          </.link>
          <button
            phx-click="refresh_stats"
            class="bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700 focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
          >
            Refresh Stats
          </button>
        </div>
      </div>
      
    <!-- Statistics Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="bg-white p-6 rounded-lg shadow">
          <div class="flex items-center">
            <div class="p-3 rounded-full bg-blue-100">
              <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
                >
                </path>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-600">Total Generated</p>
              <p class="text-2xl font-semibold text-gray-900">{@token_stats.total}</p>
            </div>
          </div>
        </div>

        <div class="bg-white p-6 rounded-lg shadow">
          <div class="flex items-center">
            <div class="p-3 rounded-full bg-green-100">
              <svg
                class="h-6 w-6 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-600">Active Tokens</p>
              <p class="text-2xl font-semibold text-gray-900">{@token_stats.active}</p>
            </div>
          </div>
        </div>

        <div class="bg-white p-6 rounded-lg shadow">
          <div class="flex items-center">
            <div class="p-3 rounded-full bg-purple-100">
              <svg
                class="h-6 w-6 text-purple-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M5 13l4 4L19 7"
                >
                </path>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-600">Completed</p>
              <p class="text-2xl font-semibold text-gray-900">{@token_stats.used}</p>
            </div>
          </div>
        </div>

        <div class="bg-white p-6 rounded-lg shadow">
          <div class="flex items-center">
            <div class="p-3 rounded-full bg-gray-100">
              <svg class="h-6 w-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                >
                </path>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm text-gray-600">Expired</p>
              <p class="text-2xl font-semibold text-gray-900">{@token_stats.expired}</p>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Search Section -->
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Search Tokens</h2>
          <p class="text-sm text-gray-600">Search by IC number, token, or birth place code</p>
        </div>
        <form phx-change="search" class="flex gap-4">
          <input
            type="text"
            name="search"
            value={@search_term}
            placeholder="Enter IC number, token, or birth place code..."
            class="flex-1 px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
          />
        </form>

        <%= if @search_term != "" and length(@filtered_tokens) > 0 do %>
          <div class="mt-4">
            <h3 class="text-md font-medium text-gray-900 mb-2">
              Search Results ({length(@filtered_tokens)} found)
            </h3>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      IC Number
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Demographics
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Created
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Expires
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Used
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= for token <- @filtered_tokens do %>
                    <tr>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                        {token.ic_number}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <%= if token.age do %>
                          <div>{token.age} years, {token.gender}</div>
                          <div class="text-xs text-gray-500">Place: {token.birth_place_code}</div>
                        <% else %>
                          <span class="text-gray-400">No demographics</span>
                        <% end %>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_class(token_status(token))}"}>
                          {status_text(token_status(token))}
                        </span>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {format_datetime(token.created_at)}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {format_datetime(token.expires_at)}
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {format_datetime(token.used_at)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>

        <%= if @search_term != "" and length(@filtered_tokens) == 0 do %>
          <div class="mt-4 text-center py-4 text-gray-500">
            No tokens found matching "{@search_term}"
          </div>
        <% end %>
      </div>
      
    <!-- Recent Tokens -->
      <div class="bg-white p-6 rounded-lg shadow">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Recent Tokens</h2>
          <span class="text-sm text-gray-500">Last 10 tokens created</span>
        </div>

        <%= if length(@recent_tokens) > 0 do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    IC Number
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Demographics
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Expires
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Used
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for token <- @recent_tokens do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                      {token.ic_number}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= if token.age do %>
                        <div>{token.age} years, {token.gender}</div>
                        <div class="text-xs text-gray-500">Place: {token.birth_place_code}</div>
                      <% else %>
                        <span class="text-gray-400">No demographics</span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_class(token_status(token))}"}>
                        {status_text(token_status(token))}
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {format_datetime(token.created_at)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {format_datetime(token.expires_at)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {format_datetime(token.used_at)}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="text-center py-8 text-gray-500">
            <svg
              class="mx-auto h-12 w-12 text-gray-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              >
              </path>
            </svg>
            <p class="mt-2">No tokens created yet</p>
            <p class="text-sm">Start by creating your first survey token</p>
          </div>
        <% end %>
      </div>
      
    <!-- Editor Guidelines -->
      <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">Editor Guidelines</h3>
            <div class="mt-2 text-sm text-yellow-700">
              <ul class="list-disc list-inside space-y-1">
                <li>Verify participant identity before generating tokens</li>
                <li>Ensure IC numbers are correctly entered (12 digits)</li>
                <li>Monitor token usage and expiration dates</li>
                <li>Report any suspicious activity to administrators</li>
                <li>Keep participant information confidential</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
