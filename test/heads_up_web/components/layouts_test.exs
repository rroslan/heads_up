defmodule HeadsUpWeb.LayoutsTest do
  use HeadsUpWeb.ConnCase

  import Phoenix.LiveViewTest
  import HeadsUp.AccountsFixtures

  describe "app layout navigation" do
    test "authenticated user can access token page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Visit a page that uses the app layout
      conn = get(conn, ~p"/")
      _html = html_response(conn, 200)

      # The navigation should be in the layout
      # We can't easily test the exact HTML here, but we can verify
      # that the Token route is accessible for authenticated users
      {:ok, _view, _html} = live(conn, ~p"/token")
    end

    test "unauthenticated user cannot access token page", %{conn: conn} do
      # Unauthenticated users should be redirected to login
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/token")
    end

    test "admin user can access both token and user management", %{conn: conn} do
      admin_user = user_fixture(%{is_admin: true})
      conn = log_in_user(conn, admin_user)

      # Admin can access token generation
      {:ok, _view, _html} = live(conn, ~p"/token")

      # Admin can also access user management
      {:ok, _view, _html} = live(conn, ~p"/users")
    end

    test "regular user cannot access user management", %{conn: conn} do
      user = user_fixture(%{is_admin: false})
      conn = log_in_user(conn, user)

      # Regular user can access token generation
      {:ok, _view, _html} = live(conn, ~p"/token")

      # But cannot access user management
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/users")
    end
  end

  describe "navigation workflow" do
    test "user login flow to token generation", %{conn: conn} do
      user = user_fixture()

      # Start unauthenticated - cannot access token page
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/token")

      # Log in
      conn = log_in_user(conn, user)

      # Now can access token page
      {:ok, view, html} = live(conn, ~p"/token")
      assert html =~ "Survey Token Generator"
      assert html =~ "User Authentication Required"

      # Can generate a token
      html =
        view
        |> form("form", %{"ic_number" => "501007081234"})
        |> render_submit()

      assert html =~ "Survey Token Generated Successfully"
    end
  end
end
