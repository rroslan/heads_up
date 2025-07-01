defmodule HeadsUpWeb.TokenLive.Survey do
  use HeadsUpWeb, :live_view

  alias HeadsUp.Surveys

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Surveys.validate_survey_token(token) do
      {:ok, survey_token} ->
        {:ok,
         socket
         |> assign(:survey_token, survey_token)
         |> assign(:token, token)
         |> assign(:error, nil)
         |> assign(:survey_completed, false)}

      {:error, :invalid_token} ->
        {:ok,
         socket
         |> assign(:survey_token, nil)
         |> assign(:token, token)
         |> assign(:error, "Invalid or expired token")
         |> assign(:survey_completed, false)}
    end
  end

  @impl true
  def handle_event("complete_survey", _params, socket) do
    case Surveys.use_survey_token(socket.assigns.token) do
      {:ok, _used_token} ->
        {:noreply,
         socket
         |> assign(:survey_completed, true)
         |> assign(:error, nil)}

      {:error, :invalid_token} ->
        {:noreply,
         socket
         |> assign(:error, "Token has expired or is no longer valid")
         |> assign(:survey_completed, false)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <%= if @error do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <div class="flex justify-center mb-4">
            <svg class="h-12 w-12 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.728-.833-2.498 0L4.316 16.5c-.77.833.192 2.5 1.732 2.5z"
              />
            </svg>
          </div>
          <h2 class="text-xl font-bold text-red-800 mb-2">Access Denied</h2>
          <p class="text-red-700 mb-4">{@error}</p>
          <div class="space-y-2">
            <p class="text-sm text-red-600">This could happen if:</p>
            <ul class="text-sm text-red-600 list-disc list-inside space-y-1">
              <li>The token has expired (tokens are valid for 24 hours)</li>
              <li>The token has already been used</li>
              <li>The token is invalid or corrupted</li>
            </ul>
          </div>
          <div class="mt-6">
            <a
              href={~p"/token"}
              class="bg-blue-600 text-white px-6 py-2 rounded-md hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
            >
              Generate New Token
            </a>
          </div>
        </div>
      <% else %>
        <%= if @survey_completed do %>
          <div class="bg-green-50 border border-green-200 rounded-lg p-8 text-center">
            <div class="flex justify-center mb-4">
              <svg
                class="h-16 w-16 text-green-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-green-800 mb-4">Survey Completed!</h2>
            <p class="text-green-700 mb-6">
              Thank you for participating in our survey. Your responses have been recorded.
            </p>
            <div class="bg-white border border-green-300 rounded-md p-4">
              <p class="text-sm text-green-600">
                Your token has been marked as used and is no longer valid. If you need to access another survey, please generate a new token.
              </p>
            </div>
          </div>
        <% else %>
          <div class="bg-white shadow-lg rounded-lg">
            <!-- Survey Header -->
            <div class="bg-blue-600 text-white p-6 rounded-t-lg">
              <h1 class="text-2xl font-bold mb-2">Health Survey</h1>
              <p class="text-blue-100">
                Please complete this survey based on your demographic information.
              </p>
            </div>
            
    <!-- Participant Information -->
            <div class="p-6 border-b border-gray-200">
              <h2 class="text-lg font-semibold text-gray-800 mb-4">Participant Information</h2>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                <div class="bg-gray-50 p-3 rounded">
                  <span class="font-medium text-gray-600">Age:</span>
                  <div class="text-lg font-bold text-gray-800">{@survey_token.age}</div>
                </div>
                <div class="bg-gray-50 p-3 rounded">
                  <span class="font-medium text-gray-600">Gender:</span>
                  <div class="text-lg font-bold text-gray-800">
                    {if @survey_token.gender == "M", do: "Male", else: "Female"}
                  </div>
                </div>
                <div class="bg-gray-50 p-3 rounded">
                  <span class="font-medium text-gray-600">Birth Date:</span>
                  <div class="text-lg font-bold text-gray-800">
                    {Calendar.strftime(@survey_token.birth_date, "%d/%m/%Y")}
                  </div>
                </div>
                <div class="bg-gray-50 p-3 rounded">
                  <span class="font-medium text-gray-600">Region:</span>
                  <div class="text-lg font-bold text-gray-800">{@survey_token.birth_place_code}</div>
                </div>
              </div>
            </div>
            
    <!-- Survey Content -->
            <div class="p-6">
              <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
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
                    <h3 class="text-sm font-medium text-yellow-800">Survey Under Development</h3>
                    <div class="mt-2 text-sm text-yellow-700">
                      <p>
                        The actual survey questions and form are currently being developed.
                        This is a placeholder page to demonstrate the token validation system.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div class="space-y-6">
                <div class="text-center">
                  <h3 class="text-lg font-medium text-gray-900 mb-4">Survey Questions Coming Soon</h3>
                  <p class="text-gray-600 mb-6">
                    This area will contain the actual survey questions once they are finalized.
                    For now, you can simulate completing the survey by clicking the button below.
                  </p>
                </div>
                
    <!-- Placeholder for actual survey questions -->
                <div class="bg-gray-50 border-2 border-dashed border-gray-300 rounded-lg p-8 text-center">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    stroke="currentColor"
                    fill="none"
                    viewBox="0 0 48 48"
                  >
                    <path
                      d="M34 40h10v-4a6 6 0 00-10.712-3.714M34 40H14m20 0v-4a9.971 9.971 0 00-.712-3.714M14 40H4v-4a6 6 0 0110.713-3.714M14 40v-4c0-1.313.253-2.566.713-3.714m0 0A9.971 9.971 0 0124 24c4.004 0 7.625 2.352 9.287 6M4 32l44-44"
                      stroke-width="2"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">Survey Questions</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Health and demographic questions will be displayed here
                  </p>
                </div>
                
    <!-- Survey Completion Button -->
                <div class="text-center pt-6">
                  <button
                    phx-click="complete_survey"
                    class="bg-green-600 text-white px-8 py-3 rounded-lg font-medium hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:ring-offset-2 transition-colors"
                  >
                    Complete Survey (Demo)
                  </button>
                  <p class="text-sm text-gray-500 mt-2">
                    This will mark your token as used and complete the survey process
                  </p>
                </div>
              </div>
            </div>
            
    <!-- Token Information -->
            <div class="bg-gray-50 px-6 py-4 rounded-b-lg">
              <div class="flex items-center justify-between text-sm text-gray-600">
                <div>
                  <span class="font-medium">Token expires:</span>
                  {Calendar.strftime(@survey_token.expires_at, "%B %d, %Y at %I:%M %p UTC")}
                </div>
                <div class="flex items-center">
                  <div class="w-2 h-2 bg-green-400 rounded-full mr-2"></div>
                  <span>Token valid</span>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
