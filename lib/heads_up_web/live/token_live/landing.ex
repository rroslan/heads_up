defmodule HeadsUpWeb.TokenLive.Landing do
  use HeadsUpWeb, :live_view

  alias HeadsUp.Surveys

  on_mount {HeadsUpWeb.UserAuth, :require_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:ic_number, "")
     |> assign(:ic_info, nil)
     |> assign(:token_url, nil)
     |> assign(:error, nil)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("validate", %{"ic_number" => ic_number}, socket) do
    # Clean IC number (remove spaces, dashes, etc.)
    clean_ic = String.replace(ic_number, ~r/[^0-9]/, "")

    socket =
      socket
      |> assign(:ic_number, clean_ic)
      |> assign(:error, nil)
      |> assign(:ic_info, nil)
      |> assign(:token_url, nil)

    # If IC is complete (12 digits), parse and show info
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
    clean_ic = String.replace(ic_number, ~r/[^0-9]/, "")

    socket = assign(socket, :loading, true)

    case Surveys.create_survey_token_from_ic(clean_ic) do
      {:ok, survey_token} ->
        token_url = url(~p"/survey/#{survey_token.token}")

        {:noreply,
         socket
         |> assign(:token_url, token_url)
         |> assign(:loading, false)
         |> assign(:error, nil)}

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
  end

  @impl true
  def handle_event("copy_token", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:ic_number, "")
     |> assign(:ic_info, nil)
     |> assign(:token_url, nil)
     |> assign(:error, nil)
     |> assign(:loading, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-6 space-y-6">
      <div class="text-center">
        <h1 class="text-3xl font-bold text-gray-900 mb-2">Survey Token Generator</h1>
        <p class="text-gray-600 mb-2">
          Enter your Malaysian IC (MyKad) number to generate a survey access token
        </p>
        <div class="bg-blue-50 border border-blue-200 rounded-md p-3 mb-4">
          <div class="flex items-center justify-center">
            <svg class="h-5 w-5 text-blue-400 mr-2" viewBox="0 0 20 20" fill="currentColor">
              <path
                fill-rule="evenodd"
                d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-6-3a2 2 0 11-4 0 2 2 0 014 0zm-2 4a5 5 0 00-4.546 2.916A5.986 5.986 0 0010 16a5.986 5.986 0 004.546-2.084A5 5 0 0010 11z"
                clip-rule="evenodd"
              />
            </svg>
            <span class="text-sm font-medium text-blue-800">User Authentication Required</span>
          </div>
          <p class="text-xs text-blue-600 mt-1">
            You must be logged in to generate survey tokens for others
          </p>
        </div>
      </div>

      <div class="bg-white shadow-lg rounded-lg p-6">
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
            <p class="text-sm text-gray-500 mt-1">
              Format: YYMMDD + Place Code (2 digits) + Sequential (3 digits) + Gender (1 digit)
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

          <div class="flex space-x-3">
            <button
              type="submit"
              disabled={String.length(@ic_number) != 12 or @loading}
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
                  Generating...
                </span>
              <% else %>
                Generate Survey Token
              <% end %>
            </button>

            <%= if @ic_number != "" or @token_url do %>
              <button
                type="button"
                phx-click="reset"
                class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Reset
              </button>
            <% end %>
          </div>
        </form>

        <%= if @token_url do %>
          <div class="mt-6 p-4 bg-green-50 border border-green-200 rounded-md">
            <div class="flex items-start">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
              </div>
              <div class="ml-3 flex-1">
                <h3 class="text-sm font-medium text-green-800">
                  Survey Token Generated Successfully!
                </h3>
                <div class="mt-2">
                  <p class="text-sm text-green-700 mb-3">
                    Your personalized survey link has been generated. This token is valid for 24 hours and can only be used once.
                  </p>

                  <div class="bg-white border border-green-300 rounded p-3">
                    <div class="flex items-center justify-between">
                      <code class="text-sm font-mono text-gray-800 break-all flex-1 mr-3">
                        {@token_url}
                      </code>
                      <button
                        type="button"
                        phx-click="copy_token"
                        onclick={"navigator.clipboard.writeText('#{@token_url}')"}
                        class="flex-shrink-0 bg-green-600 text-white px-3 py-1 rounded text-sm hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                      >
                        Copy
                      </button>
                    </div>
                  </div>

                  <div class="mt-3 text-xs text-green-600">
                    <p><strong>Important:</strong></p>
                    <ul class="list-disc list-inside space-y-1">
                      <li>This link expires in 24 hours</li>
                      <li>The link can only be used once</li>
                      <li>Do not share this link with others</li>
                      <li>Keep this link safe until you complete the survey</li>
                    </ul>
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <div class="bg-gray-50 rounded-lg p-4">
        <h3 class="text-sm font-medium text-gray-800 mb-2">How it works:</h3>
        <div class="text-sm text-gray-600 space-y-1">
          <p><strong>1-6 digits:</strong> Birth date (YYMMDD) - determines your age</p>
          <p><strong>7-8 digits:</strong> Place of birth code - indicates where you were born</p>
          <p><strong>9-11 digits:</strong> Sequential registration number</p>
          <p><strong>12th digit:</strong> Gender indicator (odd = male, even = female)</p>
        </div>
      </div>
    </div>
    """
  end
end
