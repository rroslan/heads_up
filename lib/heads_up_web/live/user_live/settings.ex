defmodule HeadsUpWeb.UserLive.Settings do
  use HeadsUpWeb, :live_view

  on_mount {HeadsUpWeb.UserAuth, :require_sudo_mode}

  alias HeadsUp.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header class="text-center">
        Account Settings
        <:subtitle>Manage your account email address and IC number</:subtitle>
      </.header>

      <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
        <.input
          field={@email_form[:email]}
          type="email"
          label="Email"
          autocomplete="username"
          required
        />
        <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
      </.form>

      <div class="divider" />

      <div class="card bg-base-100 border border-base-200 mt-6">
        <div class="card-body">
          <h3 class="card-title">Malaysian IC Number</h3>
          <p class="text-sm text-gray-600 mb-4">
            Set your IC number to view survey tokens created for you by coordinators.
          </p>

          <.form for={@ic_form} id="ic_form" phx-submit="update_ic" phx-change="validate_ic">
            <.input
              field={@ic_form[:ic_number]}
              type="text"
              label="IC Number (12 digits)"
              placeholder="e.g., 501007081234"
              maxlength="12"
              class="font-mono"
            />
            <%= if @current_ic do %>
              <p class="text-xs text-green-600 mt-1">
                Current IC: <span class="font-mono">{@current_ic}</span>
              </p>
            <% end %>
            <.button variant="primary" phx-disable-with="Updating...">Update IC Number</.button>
          </.form>
        </div>
      </div>

      <div class="divider" />
    </Layouts.app>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_email: false)
    ic_changeset = Accounts.change_user_ic(user)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:current_ic, user.ic_number)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:ic_form, to_form(ic_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_email: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("validate_ic", params, socket) do
    %{"user" => user_params} = params

    ic_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_ic(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, ic_form: ic_form)}
  end

  def handle_event("update_ic", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user

    # Clean IC number
    clean_ic = String.replace(user_params["ic_number"] || "", ~r/[^0-9]/, "")
    cleaned_params = Map.put(user_params, "ic_number", clean_ic)

    case Accounts.update_user_ic(user, cleaned_params) do
      {:ok, _updated_user} ->
        {:noreply,
         socket
         |> assign(:current_ic, clean_ic)
         |> put_flash(:info, "IC number updated successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :ic_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end
end
