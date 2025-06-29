defmodule HeadsUpWeb.UserLive.Management do
  use HeadsUpWeb, :live_view

  alias HeadsUp.Accounts
  alias HeadsUp.Accounts.User

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-8">
        <.header>
          <p>User Management</p>
          <:subtitle>
            Manage users and their roles
          </:subtitle>
        </.header>
        
    <!-- User Registration Form -->
        <div class="card bg-base-100 border border-base-200">
          <div class="card-body">
            <h2 class="card-title">Register New User</h2>

            <.form
              :let={f}
              for={@registration_form}
              id="registration_form"
              phx-submit="register_user"
              phx-change="validate_registration"
            >
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />

                <div class="space-y-2">
                  <label class="label">
                    <span class="label-text">Roles</span>
                  </label>
                  <div class="form-control">
                    <label class="label cursor-pointer justify-start gap-2">
                      <.input field={f[:is_admin]} type="checkbox" class="checkbox" />
                      <span class="label-text">Administrator</span>
                    </label>
                  </div>
                  <div class="form-control">
                    <label class="label cursor-pointer justify-start gap-2">
                      <.input field={f[:is_editor]} type="checkbox" class="checkbox" />
                      <span class="label-text">Editor</span>
                    </label>
                  </div>
                </div>
              </div>

              <div class="card-actions justify-end mt-4">
                <.button class="btn-primary" phx-disable-with="Creating user...">
                  Register User
                </.button>
              </div>
            </.form>
          </div>
        </div>
        
    <!-- Users List -->
        <div class="card bg-base-100 border border-base-200">
          <div class="card-body">
            <h2 class="card-title">Existing Users</h2>

            <div class="overflow-x-auto">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>Email</th>
                    <th>Status</th>
                    <th>Admin</th>
                    <th>Editor</th>
                    <th>Registered</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={user <- @users} id={"user-#{user.id}"}>
                    <td class="font-medium">{user.email}</td>
                    <td>
                      <span class={[
                        "badge badge-sm",
                        (user.confirmed_at && "badge-success") || "badge-warning"
                      ]}>
                        {(user.confirmed_at && "Confirmed") || "Pending"}
                      </span>
                    </td>
                    <td>
                      <span :if={user.is_admin} class="badge badge-error badge-sm">Admin</span>
                    </td>
                    <td>
                      <span :if={user.is_editor} class="badge badge-info badge-sm">Editor</span>
                    </td>
                    <td class="text-sm text-base-content/70">
                      {Calendar.strftime(user.inserted_at, "%Y-%m-%d")}
                    </td>
                    <td>
                      <div class="flex gap-2">
                        <.button
                          class="btn-xs btn-outline"
                          phx-click="edit_user"
                          phx-value-id={user.id}
                        >
                          Edit
                        </.button>
                        <.button
                          :if={!user.confirmed_at}
                          class="btn-xs btn-primary"
                          phx-click="send_login_link"
                          phx-value-id={user.id}
                        >
                          Send Login Link
                        </.button>
                        <.button
                          :if={user.id != @current_scope.user.id}
                          class="btn-xs btn-error"
                          phx-click="delete_user"
                          phx-value-id={user.id}
                          data-confirm="Are you sure you want to delete this user? This action cannot be undone."
                        >
                          Delete
                        </.button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
        
    <!-- Edit User Modal -->
        <div :if={@show_edit_modal} class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Edit User Roles</h3>

            <.form :let={f} for={@edit_form} id="edit_user_form" phx-submit="update_user_roles">
              <div class="py-4 space-y-4">
                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Email</span>
                  </label>
                  <span class="text-base-content/70">{@editing_user.email}</span>
                </div>

                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-2">
                    <.input field={f[:is_admin]} type="checkbox" class="checkbox" />
                    <span class="label-text">Administrator</span>
                  </label>
                  <div class="text-xs text-base-content/60 ml-6">
                    Full access to all features and user management
                  </div>
                </div>

                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-2">
                    <.input field={f[:is_editor]} type="checkbox" class="checkbox" />
                    <span class="label-text">Editor</span>
                  </label>
                  <div class="text-xs text-base-content/60 ml-6">
                    Can edit content but not manage users
                  </div>
                </div>
              </div>

              <div class="modal-action">
                <.button type="button" class="btn-ghost" phx-click="cancel_edit">
                  Cancel
                </.button>
                <.button class="btn-primary" phx-disable-with="Updating...">
                  Update Roles
                </.button>
              </div>
            </.form>
          </div>
        </div>
        
    <!-- Delete Confirmation Modal -->
        <div :if={@show_delete_modal} class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg text-error">Delete User</h3>

            <div class="py-4">
              <p>Are you sure you want to delete the user:</p>
              <p class="font-semibold text-lg mt-2">{@deleting_user.email}</p>
              <p class="text-sm text-base-content/60 mt-2">
                This action cannot be undone. All user data will be permanently deleted.
              </p>
            </div>

            <div class="modal-action">
              <.button type="button" class="btn-ghost" phx-click="cancel_delete">
                Cancel
              </.button>
              <.button class="btn-error" phx-click="confirm_delete" phx-disable-with="Deleting...">
                Delete User
              </.button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    users = Accounts.list_users()

    registration_changeset = Accounts.change_user_email(%User{})

    socket =
      socket
      |> assign(:users, users)
      |> assign(:show_edit_modal, false)
      |> assign(:editing_user, nil)
      |> assign(:show_delete_modal, false)
      |> assign(:deleting_user, nil)
      |> assign_registration_form(registration_changeset)
      |> assign(:edit_form, nil)

    {:ok, socket}
  end

  def handle_event("validate_registration", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> Accounts.change_user_email(user_params, validate_email: false)
      |> Map.put(:action, :validate)

    {:noreply, assign_registration_form(socket, changeset)}
  end

  def handle_event("register_user", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Send login instructions
        Accounts.deliver_login_instructions(
          user,
          &url(~p"/users/log-in/#{&1}")
        )

        # Update users list
        users = Accounts.list_users()

        # Reset form
        changeset = Accounts.change_user_email(%User{})

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign_registration_form(changeset)
         |> put_flash(
           :info,
           "User #{user.email} registered successfully! Login instructions sent."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_registration_form(socket, changeset)}
    end
  end

  def handle_event("edit_user", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    changeset = Accounts.change_user_roles(user)

    {:noreply,
     socket
     |> assign(:show_edit_modal, true)
     |> assign(:editing_user, user)
     |> assign(:edit_form, to_form(changeset))}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:editing_user, nil)
     |> assign(:edit_form, nil)}
  end

  def handle_event("update_user_roles", %{"user" => user_params}, socket) do
    case Accounts.update_user_roles(socket.assigns.editing_user, user_params) do
      {:ok, _user} ->
        users = Accounts.list_users()

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:show_edit_modal, false)
         |> assign(:editing_user, nil)
         |> assign(:edit_form, nil)
         |> put_flash(:info, "User roles updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(:edit_form, to_form(changeset))}
    end
  end

  def handle_event("send_login_link", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    Accounts.deliver_login_instructions(
      user,
      &url(~p"/users/log-in/#{&1}")
    )

    {:noreply,
     socket
     |> put_flash(:info, "Login link sent to #{user.email}")}
  end

  def handle_event("delete_user", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    {:noreply,
     socket
     |> assign(:show_delete_modal, true)
     |> assign(:deleting_user, user)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_modal, false)
     |> assign(:deleting_user, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    case Accounts.delete_user(socket.assigns.deleting_user) do
      {:ok, _user} ->
        users = Accounts.list_users()

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:show_delete_modal, false)
         |> assign(:deleting_user, nil)
         |> put_flash(:info, "User deleted successfully!")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to delete user. Please try again.")}
    end
  end

  defp assign_registration_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :registration_form, to_form(changeset, as: "user"))
  end
end
