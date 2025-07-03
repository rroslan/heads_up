defmodule HeadsUpWeb.TokenLive.Landing do
  use HeadsUpWeb, :live_view

  alias HeadsUp.Surveys

  on_mount {HeadsUpWeb.UserAuth, :require_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user
    can_generate = can_generate_tokens?(current_user)

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:user_role, get_user_role(current_user))
     |> assign(:can_generate, can_generate)
     |> load_user_tokens()
     |> assign(:show_generate_form, false)
     |> assign(:ic_number, "")
     |> assign(:ic_info, nil)
     |> assign(:token_url, nil)
     |> assign(:error, nil)
     |> assign(:loading, false)
     |> assign(:search_term, "")
     |> assign(:filtered_tokens, [])
     |> assign(:show_used_tokens, true)
     |> assign(:show_active_tokens, true)
     |> assign(:show_expired_tokens, false)
     |> assign(:needs_ic_setup, false)}
  end

  defp load_user_tokens(socket) do
    current_user = socket.assigns.current_user

    if current_user.is_admin or current_user.is_editor do
      # Editors/Admins see tokens they created
      tokens = Surveys.list_survey_tokens_by_user(current_user)
      stats = Surveys.get_user_token_stats(current_user)

      socket
      |> assign(:tokens, tokens)
      |> assign(:token_stats, stats)
    else
      # Regular users see ALL tokens for distribution
      tokens = Surveys.list_survey_tokens()

      stats = %{
        total: length(tokens),
        used: Enum.count(tokens, fn t -> t.used_at end),
        expired:
          Enum.count(tokens, fn t ->
            DateTime.compare(DateTime.utc_now(), t.expires_at) == :gt and !t.used_at
          end),
        active:
          Enum.count(tokens, fn t ->
            DateTime.compare(DateTime.utc_now(), t.expires_at) == :lt and !t.used_at
          end)
      }

      socket
      |> assign(:tokens, tokens)
      |> assign(:token_stats, stats)
    end
  end

  @impl true
  def handle_event("toggle_generate_form", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_generate_form, !socket.assigns.show_generate_form)
     |> assign(:ic_number, "")
     |> assign(:ic_info, nil)
     |> assign(:token_url, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("validate", %{"ic_number" => ic_number}, socket) do
    clean_ic = String.replace(ic_number, ~r/[^0-9]/, "")

    socket =
      socket
      |> assign(:ic_number, clean_ic)
      |> assign(:error, nil)
      |> assign(:ic_info, nil)
      |> assign(:token_url, nil)

    socket =
      if String.length(clean_ic) == 12 do
        case Surveys.get_ic_info(clean_ic) do
          {:ok, info} ->
            assign(socket, :ic_info, info)

          {:error, reason} ->
            assign(socket, :error, reason)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_token", %{"ic_number" => ic_number}, socket) do
    # Only editors and admins can generate tokens
    if socket.assigns.current_user.is_admin or socket.assigns.current_user.is_editor do
      clean_ic = String.replace(ic_number, ~r/[^0-9]/, "")
      socket = assign(socket, :loading, true)
      current_user = socket.assigns.current_scope.user

      case Surveys.create_survey_token_from_ic(clean_ic, current_user) do
        {:ok, survey_token} ->
          token_url = url(~p"/survey/#{survey_token.token}")

          # Refresh the tokens list
          updated_tokens = Surveys.list_survey_tokens_by_user(current_user)
          updated_stats = Surveys.get_user_token_stats(current_user)

          {:noreply,
           socket
           |> assign(:token_url, token_url)
           |> assign(:tokens, updated_tokens)
           |> assign(:token_stats, updated_stats)
           |> assign(:loading, false)
           |> assign(:error, nil)
           |> assign(:show_generate_form, false)
           |> assign(:ic_number, "")
           |> assign(:ic_info, nil)
           |> put_flash(:info, "Survey token generated successfully!")}

        {:error, %Ecto.Changeset{} = changeset} ->
          error_msg =
            changeset.errors
            |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
            |> Enum.join(", ")

          {:noreply,
           socket
           |> assign(:error, error_msg)
           |> assign(:loading, false)}

        {:error, reason} when is_binary(reason) ->
          {:noreply,
           socket
           |> assign(:error, reason)
           |> assign(:loading, false)}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:error, "Failed to generate token: #{inspect(reason)}")
           |> assign(:loading, false)}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to generate tokens.")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    tokens = socket.assigns.tokens

    filtered_tokens =
      if String.trim(search_term) == "" do
        []
      else
        filter_tokens(tokens, String.downcase(search_term))
      end

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:filtered_tokens, filtered_tokens)}
  end

  @impl true
  def handle_event("toggle_filter", %{"filter" => filter}, socket) do
    updated_socket =
      case filter do
        "used" -> assign(socket, :show_used_tokens, !socket.assigns.show_used_tokens)
        "active" -> assign(socket, :show_active_tokens, !socket.assigns.show_active_tokens)
        "expired" -> assign(socket, :show_expired_tokens, !socket.assigns.show_expired_tokens)
        _ -> socket
      end

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("refresh_tokens", _params, socket) do
    _current_user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> load_user_tokens()
     |> put_flash(:info, "Token list refreshed")}
  end

  @impl true
  def handle_event("copy_token", %{"token" => _token}, socket) do
    # The actual copying happens in JavaScript, this is just for feedback
    {:noreply, put_flash(socket, :info, "Survey link copied to clipboard!")}
  end

  @impl true
  def handle_event("share_sms", %{"token" => token, "ic" => ic_number}, socket) do
    survey_url = url(~p"/survey/#{token}")

    sms_body =
      "Hi! Please complete your survey using this link: #{survey_url} (IC: #{ic_number}). Valid for 24 hours."

    sms_url = "sms:?body=#{URI.encode(sms_body)}"

    {:noreply,
     socket
     |> put_flash(:info, "SMS app opened with survey link")
     |> push_event("open_sms", %{url: sms_url})}
  end

  defp get_user_role(user) do
    cond do
      user.is_admin -> "Administrator"
      user.is_editor -> "Editor"
      true -> "User"
    end
  end

  defp can_generate_tokens?(user) do
    user.is_admin or user.is_editor
  end

  defp filter_tokens(tokens, search_term) do
    Enum.filter(tokens, fn token ->
      String.contains?(String.downcase(token.ic_number), search_term) or
        String.contains?(String.downcase(token.token), search_term) or
        (token.birth_place_code &&
           String.contains?(String.downcase(token.birth_place_code), search_term))
    end)
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

  defp format_datetime(datetime) do
    case datetime do
      nil -> "-"
      dt -> Calendar.strftime(dt, "%Y-%m-%d %H:%M")
    end
  end

  defp should_show_token?(token, show_used, show_active, show_expired) do
    case token_status(token) do
      :used -> show_used
      :active -> show_active
      :expired -> show_expired
    end
  end

  defp get_visible_tokens(
         tokens,
         search_term,
         filtered_tokens,
         show_used,
         show_active,
         show_expired
       ) do
    tokens_to_filter =
      if String.trim(search_term) != "" and length(filtered_tokens) > 0 do
        filtered_tokens
      else
        tokens
      end

    Enum.filter(tokens_to_filter, fn token ->
      should_show_token?(token, show_used, show_active, show_expired)
    end)
  end

  @impl true
  def render(assigns) do
    visible_tokens =
      get_visible_tokens(
        assigns.tokens,
        assigns.search_term,
        assigns.filtered_tokens,
        assigns.show_used_tokens,
        assigns.show_active_tokens,
        assigns.show_expired_tokens
      )

    assigns = assign(assigns, :visible_tokens, visible_tokens)

    ~H"""
    <div class="max-w-7xl mx-auto p-6 space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">
            <%= if @can_generate do %>
              Survey Token Management
            <% else %>
              Survey Token Distribution
            <% end %>
          </h1>
          <p class="text-gray-600">
            <%= if @can_generate do %>
              Generate and manage survey tokens for distribution to participants
            <% else %>
              Copy and distribute survey tokens to participants
            <% end %>
          </p>
        </div>
        <div class="flex space-x-3">
          <%= if @can_generate do %>
            <button
              phx-click="toggle_generate_form"
              class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            >
              {if @show_generate_form, do: "Cancel", else: "Generate New Token"}
            </button>
          <% end %>
          <%= if @current_user.is_admin or @current_user.is_editor do %>
            <.link
              navigate={~p"/editor/dashboard"}
              class="bg-gray-600 text-white px-4 py-2 rounded-md hover:bg-gray-700 focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
            >
              Dashboard
            </.link>
          <% end %>
        </div>
      </div>
      
    <!-- User Info -->
      <div class="bg-green-50 border border-green-200 rounded-md p-3">
        <div class="flex items-center justify-center">
          <svg class="h-5 w-5 text-green-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
              clip-rule="evenodd"
            />
          </svg>
          <span class="text-sm font-medium text-green-800">Authorized as {@user_role}</span>
        </div>
        <p class="text-xs text-green-600 mt-1 text-center">
          <%= if @can_generate do %>
            You can create and manage survey tokens for participants
          <% else %>
            You can copy and distribute survey tokens to participants
          <% end %>
        </p>
      </div>
      
    <!-- Statistics Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="bg-blue-50 p-4 rounded-lg">
          <div class="text-2xl font-bold text-blue-600">{@token_stats.total}</div>
          <div class="text-sm text-blue-700">Total Generated</div>
        </div>
        <div class="bg-green-50 p-4 rounded-lg">
          <div class="text-2xl font-bold text-green-600">{@token_stats.active}</div>
          <div class="text-sm text-green-700">Active Tokens</div>
        </div>
        <div class="bg-purple-50 p-4 rounded-lg">
          <div class="text-2xl font-bold text-purple-600">{@token_stats.used}</div>
          <div class="text-sm text-purple-700">Completed</div>
        </div>
        <div class="bg-gray-50 p-4 rounded-lg">
          <div class="text-2xl font-bold text-gray-600">{@token_stats.expired}</div>
          <div class="text-sm text-gray-700">Expired</div>
        </div>
      </div>
      
    <!-- Generate Token Form (Collapsible) - Only for editors/admins -->
      <%= if @can_generate and @show_generate_form do %>
        <div class="bg-white shadow-lg rounded-lg p-6">
          <h2 class="text-lg font-semibold text-gray-900 mb-4">Generate New Survey Token</h2>

          <form phx-change="validate" phx-submit="generate_token" class="space-y-4">
            <div>
              <label for="ic_number" class="block text-sm font-medium text-gray-700 mb-2">
                Malaysian IC Number (12 digits)
              </label>
              <input
                type="text"
                id="ic_number"
                name="ic_number"
                value={@ic_number}
                placeholder="e.g., 501007081234"
                maxlength="12"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-lg font-mono"
              />
            </div>

            <%= if @error do %>
              <div class="bg-red-50 border border-red-200 rounded-md p-3">
                <p class="text-sm text-red-700">{@error}</p>
              </div>
            <% end %>

            <%= if @ic_info do %>
              <div class="bg-blue-50 border border-blue-200 rounded-md p-4">
                <h3 class="text-sm font-medium text-blue-800 mb-2">IC Information Preview</h3>
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="font-medium">Birth Date:</span>
                    {Calendar.strftime(@ic_info.birth_date, "%B %d, %Y")}
                  </div>
                  <div>
                    <span class="font-medium">Age:</span>
                    {@ic_info.age} years old
                  </div>
                  <div>
                    <span class="font-medium">Gender:</span>
                    {if @ic_info.gender == "M", do: "Male", else: "Female"}
                  </div>
                  <div>
                    <span class="font-medium">Birth Place Code:</span>
                    {@ic_info.birth_place_code}
                  </div>
                </div>
              </div>
            <% end %>

            <button
              type="submit"
              disabled={String.length(@ic_number) != 12 or @loading}
              class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <%= if @loading do %>
                <span class="flex items-center justify-center">
                  <svg
                    class="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  Generating...
                </span>
              <% else %>
                Generate Survey Token
              <% end %>
            </button>
          </form>
        </div>
      <% end %>
      
    <!-- Search and Filters -->
      <div class="bg-white shadow rounded-lg p-6">
        <div class="flex flex-col md:flex-row gap-4 items-start md:items-end">
          <div class="flex-1">
            <label for="search" class="block text-sm font-medium text-gray-700 mb-2">
              Search Tokens
            </label>
            <form phx-change="search">
              <input
                type="text"
                name="search"
                value={@search_term}
                placeholder="Search by IC number, token, or birth place..."
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500"
              />
            </form>
          </div>

          <div class="flex flex-wrap gap-2">
            <span class="text-sm font-medium text-gray-700">Show:</span>
            <label class="flex items-center">
              <input
                type="checkbox"
                checked={@show_active_tokens}
                phx-click="toggle_filter"
                phx-value-filter="active"
                class="rounded border-gray-300 text-green-600 focus:ring-green-500"
              />
              <span class="ml-1 text-sm text-gray-600">Active</span>
            </label>
            <label class="flex items-center">
              <input
                type="checkbox"
                checked={@show_used_tokens}
                phx-click="toggle_filter"
                phx-value-filter="used"
                class="rounded border-gray-300 text-purple-600 focus:ring-purple-500"
              />
              <span class="ml-1 text-sm text-gray-600">Used</span>
            </label>
            <label class="flex items-center">
              <input
                type="checkbox"
                checked={@show_expired_tokens}
                phx-click="toggle_filter"
                phx-value-filter="expired"
                class="rounded border-gray-300 text-gray-600 focus:ring-gray-500"
              />
              <span class="ml-1 text-sm text-gray-600">Expired</span>
            </label>
          </div>

          <button
            phx-click="refresh_tokens"
            class="px-4 py-2 bg-gray-100 text-gray-700 rounded-md hover:bg-gray-200 focus:ring-2 focus:ring-gray-500"
          >
            Refresh
          </button>
        </div>
      </div>
      
    <!-- Tokens List -->
      <div class="bg-white shadow rounded-lg overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200">
          <h2 class="text-lg font-semibold text-gray-900">
            <%= if @can_generate do %>
              Your Survey Tokens ({length(@visible_tokens)})
            <% else %>
              Available Survey Tokens ({length(@visible_tokens)})
            <% end %>
          </h2>
          <p class="text-sm text-gray-600">
            Click on survey links to copy for SMS/sharing to participants
          </p>
        </div>

        <%= if length(@visible_tokens) > 0 do %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Participant Info
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Survey Link
                  </th>
                  <%= if not @can_generate do %>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Created By
                    </th>
                  <% end %>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Created
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Expires/Used
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for token <- @visible_tokens do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-mono text-gray-900">{token.ic_number}</div>
                      <%= if token.age do %>
                        <div class="text-xs text-gray-500">
                          {token.age} years, {token.gender}, Place: {token.birth_place_code}
                        </div>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class={"px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_class(token_status(token))}"}>
                        {status_text(token_status(token))}
                      </span>
                    </td>
                    <td class="px-6 py-4">
                      <div class="space-y-2">
                        <button
                          phx-click="copy_token"
                          phx-value-token={token.token}
                          onclick={"navigator.clipboard.writeText('#{url(~p"/survey/#{token.token}")}')"}
                          class="w-full text-left p-2 bg-blue-50 hover:bg-blue-100 rounded border border-blue-200 focus:ring-2 focus:ring-blue-500"
                        >
                          <div class="text-xs text-blue-600 font-medium flex items-center">
                            <svg
                              class="h-3 w-3 mr-1"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
                              >
                              </path>
                            </svg>
                            Click to copy link
                          </div>
                          <div class="text-sm font-mono text-blue-800 truncate">
                            {url(~p"/survey/#{token.token}")}
                          </div>
                        </button>

                        <button
                          phx-click="share_sms"
                          phx-value-token={token.token}
                          phx-value-ic={token.ic_number}
                          class="w-full text-left p-2 bg-green-50 hover:bg-green-100 rounded border border-green-200 focus:ring-2 focus:ring-green-500"
                        >
                          <div class="text-xs text-green-600 font-medium flex items-center">
                            <svg
                              class="h-3 w-3 mr-1"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                              >
                              </path>
                            </svg>
                            Share via SMS
                          </div>
                          <div class="text-xs text-green-700">
                            Opens SMS app with survey link
                          </div>
                        </button>
                      </div>
                    </td>
                    <%= if not @can_generate do %>
                      <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <%= if token.created_by_user do %>
                          {String.split(token.created_by_user.email, "@") |> hd()}
                          <%= if token.created_by_user.is_admin do %>
                            <span class="inline-block ml-1 px-1 py-0.5 text-xs bg-red-100 text-red-600 rounded">
                              Admin
                            </span>
                          <% end %>
                          <%= if token.created_by_user.is_editor do %>
                            <span class="inline-block ml-1 px-1 py-0.5 text-xs bg-blue-100 text-blue-600 rounded">
                              Editor
                            </span>
                          <% end %>
                        <% else %>
                          <span class="text-gray-400">Unknown</span>
                        <% end %>
                      </td>
                    <% end %>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {format_datetime(token.created_at)}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      <%= if token.used_at do %>
                        <div class="text-purple-600 font-medium">Used</div>
                        <div class="text-xs text-gray-500">{format_datetime(token.used_at)}</div>
                      <% else %>
                        <div>Expires:</div>
                        <div class="text-xs text-gray-500">{format_datetime(token.expires_at)}</div>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% else %>
          <div class="text-center py-12">
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
            <h3 class="mt-2 text-sm font-medium text-gray-900">No tokens found</h3>
            <p class="mt-1 text-sm text-gray-500">
              <%= if String.trim(@search_term) != "" do %>
                No tokens match your search criteria. Try adjusting your search or filters.
              <% else %>
                <%= if @can_generate do %>
                  Get started by generating your first survey token.
                <% else %>
                  No survey tokens have been created yet. Contact an editor or administrator to create tokens.
                <% end %>
              <% end %>
            </p>
            <%= if String.trim(@search_term) == "" and @can_generate do %>
              <div class="mt-6">
                <button
                  phx-click="toggle_generate_form"
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                >
                  Generate First Token
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
    <!-- Usage Guidelines -->
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
            <h3 class="text-sm font-medium text-yellow-800">
              Token Distribution Guidelines
            </h3>
            <div class="mt-2 text-sm text-yellow-700">
              <ul class="list-disc list-inside space-y-1">
                <li><strong>Click survey links</strong> to copy them for SMS or messaging apps</li>
                <li><strong>Each token is unique</strong> to the participant's IC number</li>
                <li><strong>Tokens expire in 24 hours</strong> and can only be used once</li>
                <li>
                  <strong>Share responsibly</strong> - only send tokens to verified participants
                </li>
                <li>
                  <strong>Monitor usage</strong> to ensure participants complete their surveys
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      <script>
        window.addEventListener("phx:open_sms", (e) => {
          window.location.href = e.detail.url;
        });
      </script>
    </div>
    """
  end
end
