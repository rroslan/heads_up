defmodule HeadsUpWeb.UserLive.ManagementTest do
  use HeadsUpWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import HeadsUp.AccountsFixtures

  describe "Management page - access control" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/users")
    end

    test "redirects if user is not admin", %{conn: conn} do
      user = user_fixture(%{is_admin: false, is_editor: true})

      assert {:error, {:redirect, %{to: "/"}}} =
               conn
               |> log_in_user(user)
               |> live(~p"/users")
    end

    test "allows access for admin users", %{conn: conn} do
      admin = user_fixture(%{is_admin: true})

      {:ok, _lv, html} =
        conn
        |> log_in_user(admin)
        |> live(~p"/users")

      assert html =~ "User Management"
      assert html =~ "Register New User"
      assert html =~ "Existing Users"
    end
  end

  describe "User registration form" do
    setup %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      conn = log_in_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/users")

      %{conn: conn, lv: lv, admin: admin}
    end

    test "renders registration form", %{lv: lv} do
      html = render(lv)

      assert html =~ "Register New User"
      assert html =~ "Email"
      assert html =~ "Administrator"
      assert html =~ "Editor"
    end

    test "validates email format", %{lv: lv} do
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "invalid-email"})

      assert result =~ "must have the @ sign and no spaces"
    end

    test "creates user with roles successfully", %{lv: lv} do
      email = unique_user_email()

      lv
      |> form("#registration_form",
        user: %{
          "email" => email,
          "is_admin" => "true",
          "is_editor" => "false"
        }
      )
      |> render_submit()

      # Check flash message
      assert render(lv) =~ "User #{email} registered successfully!"

      # Verify user was created with correct roles
      user = HeadsUp.Accounts.get_user_by_email(email)
      assert user.is_admin == true
      assert user.is_editor == false
    end

    test "handles duplicate email error", %{lv: lv} do
      existing_user = user_fixture()

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => existing_user.email}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "Users list" do
    setup %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      editor = user_fixture(%{is_editor: true, is_admin: false})
      regular_user = user_fixture(%{is_admin: false, is_editor: false})

      conn = log_in_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/users")

      %{conn: conn, lv: lv, admin: admin, editor: editor, regular_user: regular_user}
    end

    test "displays all users with their roles", %{
      lv: lv,
      admin: admin,
      editor: editor,
      regular_user: regular_user
    } do
      html = render(lv)

      # Check all users are displayed
      assert html =~ admin.email
      assert html =~ editor.email
      assert html =~ regular_user.email

      # Check role badges
      assert html =~ "Admin"
      assert html =~ "Editor"
    end

    test "shows confirmation status", %{lv: lv} do
      html = render(lv)

      # Check that status badges are displayed
      assert html =~ "Confirmed"
      assert html =~ "badge-success"
    end

    test "shows send login link button for unconfirmed users", %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      _unconfirmed_user = unconfirmed_user_fixture()

      conn = log_in_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/users")

      html = render(lv)
      assert html =~ "Send Login Link"
    end
  end

  describe "Edit user roles" do
    setup %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      target_user = user_fixture(%{is_admin: false, is_editor: true})

      conn = log_in_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/users")

      %{conn: conn, lv: lv, admin: admin, target_user: target_user}
    end

    test "opens edit modal when edit button is clicked", %{lv: lv, target_user: target_user} do
      lv
      |> element("[phx-click='edit_user'][phx-value-id='#{target_user.id}']")
      |> render_click()

      html = render(lv)

      assert html =~ "Edit User Roles"
      assert html =~ target_user.email
      assert html =~ "Administrator"
      assert html =~ "Editor"
    end

    test "updates user roles successfully", %{lv: lv, target_user: target_user} do
      # Open edit modal
      lv
      |> element("[phx-click='edit_user'][phx-value-id='#{target_user.id}']")
      |> render_click()

      # Submit role changes
      lv
      |> form("#edit_user_form",
        user: %{
          "is_admin" => "true",
          "is_editor" => "false"
        }
      )
      |> render_submit()

      # Check success message
      assert render(lv) =~ "User roles updated successfully!"

      # Verify roles were updated
      updated_user = HeadsUp.Accounts.get_user!(target_user.id)
      assert updated_user.is_admin == true
      assert updated_user.is_editor == false
    end

    test "closes modal when cancel is clicked", %{lv: lv, target_user: target_user} do
      # Open edit modal
      lv
      |> element("[phx-click='edit_user'][phx-value-id='#{target_user.id}']")
      |> render_click()

      # Click cancel
      lv
      |> element("[phx-click='cancel_edit']")
      |> render_click()

      html = render(lv)
      refute html =~ "Edit User Roles"
    end
  end

  describe "Send login link" do
    setup %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      unconfirmed_user = unconfirmed_user_fixture()

      conn = log_in_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/users")

      %{conn: conn, lv: lv, admin: admin, unconfirmed_user: unconfirmed_user}
    end

    test "sends login link and shows success message", %{
      lv: lv,
      unconfirmed_user: unconfirmed_user
    } do
      lv
      |> element("[phx-click='send_login_link'][phx-value-id='#{unconfirmed_user.id}']")
      |> render_click()

      html = render(lv)
      assert html =~ "Login link sent to #{unconfirmed_user.email}"

      # Verify token was created
      assert HeadsUp.Repo.get_by(HeadsUp.Accounts.UserToken,
               user_id: unconfirmed_user.id,
               context: "login"
             )
    end
  end

  describe "Delete user" do
    setup %{conn: conn} do
      admin = user_fixture(%{is_admin: true})
      target_user = user_fixture(%{is_admin: false, is_editor: false})

      conn = log_in_user(conn, admin)
      {:ok, lv, _html} = live(conn, ~p"/users")

      %{conn: conn, lv: lv, admin: admin, target_user: target_user}
    end

    test "shows delete button for other users but not for current user", %{
      lv: lv,
      admin: _admin,
      target_user: target_user
    } do
      html = render(lv)

      # Should show delete button for target user
      assert html =~ "Delete"

      # The delete button should have the correct phx-click attribute
      assert html =~ "phx-click=\"delete_user\""
      assert html =~ "phx-value-id=\"#{target_user.id}\""
    end

    test "opens delete confirmation modal when delete button is clicked", %{
      lv: lv,
      target_user: target_user
    } do
      lv
      |> element("[phx-click='delete_user'][phx-value-id='#{target_user.id}']")
      |> render_click()

      html = render(lv)

      assert html =~ "Delete User"
      assert html =~ target_user.email
      assert html =~ "This action cannot be undone"
    end

    test "closes modal when cancel is clicked", %{lv: lv, target_user: target_user} do
      # Open delete modal
      lv
      |> element("[phx-click='delete_user'][phx-value-id='#{target_user.id}']")
      |> render_click()

      # Click cancel
      lv
      |> element("[phx-click='cancel_delete']")
      |> render_click()

      html = render(lv)
      refute html =~ "Delete User"
    end

    test "deletes user when confirmed", %{lv: lv, target_user: target_user} do
      # Open delete modal
      lv
      |> element("[phx-click='delete_user'][phx-value-id='#{target_user.id}']")
      |> render_click()

      # Confirm deletion
      lv
      |> element("[phx-click='confirm_delete']")
      |> render_click()

      # Check success message
      assert render(lv) =~ "User deleted successfully!"

      # Verify user was actually deleted
      assert_raise Ecto.NoResultsError, fn ->
        HeadsUp.Accounts.get_user!(target_user.id)
      end
    end

    test "prevents admin from deleting themselves", %{lv: lv, admin: admin} do
      html = render(lv)

      # Should not have delete button for the current admin user
      refute html =~ "[phx-value-id='#{admin.id}'][phx-click='delete_user']"
    end
  end
end
