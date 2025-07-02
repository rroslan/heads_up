defmodule HeadsUpWeb.TokenLive.Access do
  use HeadsUpWeb, :live_view

  alias HeadsUp.Surveys

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:token_input, "")
     |> assign(:error, nil)
     |> assign(:loading, false)
     |> assign(:extracted_token, nil)}
  end

  @impl true
  def handle_event("validate", %{"token_input" => token_input}, socket) do
    socket =
      socket
      |> assign(:token_input, String.trim(token_input))
      |> assign(:error, nil)
      |> assign(:extracted_token, nil)

    # Try to extract token from input
    socket =
      if String.length(socket.assigns.token_input) > 0 do
        case extract_token(socket.assigns.token_input) do
          {:ok, token} ->
            assign(socket, :extracted_token, token)

          {:error, reason} ->
            assign(socket, :error, reason)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("access_survey", %{"token_input" => token_input}, socket) do
    socket = assign(socket, :loading, true)

    case extract_token(String.trim(token_input)) do
      {:ok, token} ->
        case Surveys.validate_survey_token(token) do
          {:ok, _survey_token} ->
            {:noreply, redirect(socket, to: ~p"/survey/#{token}")}

          {:error, :invalid_token} ->
            {:noreply,
             socket
             |> assign(:error, "Invalid or expired survey token")
             |> assign(:loading, false)}
        end

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:error, reason)
         |> assign(:loading, false)}
    end
  end

  @impl true
  def handle_event("clear_input", _params, socket) do
    {:noreply,
     socket
     |> assign(:token_input, "")
     |> assign(:error, nil)
     |> assign(:extracted_token, nil)
     |> assign(:loading, false)}
  end

  # Private function to extract token from various input formats
  defp extract_token(input) when is_binary(input) do
    cond do
      # If it's already just a token (no URL structure)
      String.match?(input, ~r/^[a-zA-Z0-9_-]+$/) and String.length(input) > 10 ->
        {:ok, input}

      # If it's a full URL like https://example.com/survey/token123
      String.contains?(input, "/survey/") ->
        case String.split(input, "/survey/") do
          [_base, token | _] ->
            # Remove any query parameters or fragments
            clean_token =
              token
              |> String.split("?")
              |> List.first()
              |> String.split("#")
              |> List.first()
              |> String.trim()

            if String.length(clean_token) > 0 do
              {:ok, clean_token}
            else
              {:error, "Could not extract token from URL"}
            end

          _ ->
            {:error, "Invalid survey URL format"}
        end

      # If it looks like a URL but doesn't contain /survey/
      String.starts_with?(input, "http") ->
        {:error, "URL does not appear to be a survey link"}

      # If it's too short to be a valid token
      String.length(input) < 10 ->
        {:error, "Token appears to be too short"}

      # If it contains invalid characters
      not String.match?(input, ~r/^[a-zA-Z0-9_\-\/\.\:\?=#&]+$/) ->
        {:error, "Token contains invalid characters"}

      true ->
        {:error, "Invalid token format"}
    end
  end

  defp extract_token(_), do: {:error, "Invalid input"}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 space-y-6">
      <div class="text-center">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Access Survey</h1>
        <p class="text-gray-600 mb-4">
          Paste your survey token or survey link below to access your personalized survey
        </p>
        <div class="bg-blue-50 border border-blue-200 rounded-md p-3 mb-4">
          <div class="flex items-center justify-center">
            <svg class="h-5 w-5 text-blue-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                clip-rule="evenodd"
              />
            </svg>
            <span class="text-sm font-medium text-blue-800">Survey Token Required</span>
          </div>
          <p class="text-xs text-blue-600 mt-1">
            Use the survey link or token that was generated for you
          </p>
        </div>
      </div>

      <div class="bg-white shadow-lg rounded-lg p-6">
        <form phx-change="validate" phx-submit="access_survey" class="space-y-4">
          <div>
            <label for="token_input" class="block text-sm font-medium text-gray-700 mb-2">
              Survey Link or Token
            </label>
            <textarea
              id="token_input"
              name="token_input"
              value={@token_input}
              rows="3"
              placeholder="Paste your survey link here (e.g., https://example.com/survey/abc123) or just the token"
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 text-sm"
            />
            <p class="text-sm text-gray-500 mt-1">
              You can paste either the full survey URL or just the token string
            </p>
          </div>

          <%= if @error do %>
            <div class="bg-red-50 border border-red-200 rounded-md p-3">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
                    <path
                      fill-rule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm text-red-700">{@error}</p>
                </div>
              </div>
            </div>
          <% end %>

          <%= if @extracted_token do %>
            <div class="bg-green-50 border border-green-200 rounded-md p-3">
              <div class="flex">
                <div class="flex-shrink-0">
                  <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                    <path
                      fill-rule="evenodd"
                      d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="ml-3">
                  <p class="text-sm text-green-700">
                    <span class="font-medium">Token detected:</span>
                    <code class="bg-green-100 px-1 rounded text-xs">{@extracted_token}</code>
                  </p>
                </div>
              </div>
            </div>
          <% end %>

          <div class="flex space-x-3">
            <button
              type="submit"
              disabled={@loading or is_nil(@extracted_token)}
              class="flex-1 bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
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
                  Accessing Survey...
                </span>
              <% else %>
                Access Survey
              <% end %>
            </button>

            <%= if @token_input != "" do %>
              <button
                type="button"
                phx-click="clear_input"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Clear
              </button>
            <% end %>
          </div>
        </form>
      </div>

      <div class="bg-gray-50 rounded-lg p-4">
        <h3 class="text-sm font-medium text-gray-800 mb-2">Supported formats:</h3>
        <div class="text-sm text-gray-600 space-y-1">
          <p><strong>Full URL:</strong> https://example.com/survey/abc123def456</p>
          <p><strong>Token only:</strong> abc123def456</p>
          <p><strong>Path only:</strong> /survey/abc123def456</p>
        </div>
        <div class="mt-3 pt-3 border-t border-gray-200">
          <p class="text-xs text-gray-500">
            <strong>Note:</strong> Survey tokens are valid for 24 hours and can only be used once.
            If you need a new token, contact the person who generated it for you.
          </p>
        </div>
      </div>

      <div class="text-center">
        <p class="text-sm text-gray-500">
          Need to generate a new token?
          <a href={~p"/token"} class="text-blue-600 hover:text-blue-500 font-medium">
            Generate Token
          </a>
        </p>
      </div>
    </div>
    """
  end
end
