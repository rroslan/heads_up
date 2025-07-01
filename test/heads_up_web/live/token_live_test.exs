defmodule HeadsUpWeb.TokenLiveTest do
  use HeadsUpWeb.ConnCase

  import Phoenix.LiveViewTest
  import HeadsUp.AccountsFixtures

  alias HeadsUp.Surveys

  describe "Token Generation (User Authentication Required)" do
    test "redirects to login when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/token")
    end

    test "allows access for any authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/token")

      assert html =~ "Survey Token Generator"
      assert html =~ "User Authentication Required"
      assert html =~ "Enter your Malaysian IC"
    end

    test "allows access for admin users too", %{conn: conn} do
      admin_user = user_fixture(%{is_admin: true})
      conn = log_in_user(conn, admin_user)

      {:ok, _view, html} = live(conn, ~p"/token")

      assert html =~ "Survey Token Generator"
      assert html =~ "User Authentication Required"
      assert html =~ "Enter your Malaysian IC"
    end

    test "authenticated user can generate token with valid IC", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/token")

      # Enter valid IC number
      view
      |> form("form", %{"ic_number" => "501007081234"})
      |> render_change()

      html =
        view
        |> form("form", %{"ic_number" => "501007081234"})
        |> render_submit()

      assert html =~ "Survey Token Generated Successfully"
      assert html =~ "/survey/"
    end

    test "authenticated user sees error with invalid IC", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/token")

      # Enter invalid IC number
      html =
        view
        |> form("form", %{"ic_number" => "123"})
        |> render_change()

      # Should not show token generation for incomplete IC
      refute html =~ "Survey Token Generated Successfully"
    end

    test "shows IC information preview for valid IC", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/token")

      # Enter valid IC number that triggers info preview
      html =
        view
        |> form("form", %{"ic_number" => "501007081234"})
        |> render_change()

      assert html =~ "IC Information Preview"
      assert html =~ "Birth Date:"
      assert html =~ "Gender:"
      assert html =~ "Age:"
    end
  end

  describe "Survey Access (No Authentication Required)" do
    setup do
      # Create a valid survey token for testing
      {:ok, survey_token} = Surveys.create_survey_token_from_ic("501007081234")
      %{survey_token: survey_token}
    end

    test "allows access for unauthenticated users with valid token", %{
      conn: conn,
      survey_token: survey_token
    } do
      {:ok, _view, html} = live(conn, ~p"/survey/#{survey_token.token}")

      assert html =~ "Health Survey"
      assert html =~ "Participant Information"
      assert html =~ "Age:"
      assert html =~ "Gender:"
      assert html =~ survey_token.age |> to_string()
    end

    test "allows access for authenticated users with valid token", %{
      conn: conn,
      survey_token: survey_token
    } do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/survey/#{survey_token.token}")

      assert html =~ "Health Survey"
      assert html =~ "Participant Information"
      assert html =~ "Age:"
      assert html =~ "Gender:"
      assert html =~ survey_token.age |> to_string()
    end

    test "shows error for invalid token", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/survey/invalid_token")

      assert html =~ "Access Denied"
      assert html =~ "Invalid or expired token"
      assert html =~ "Generate New Token"
    end

    test "unauthenticated user can complete survey", %{conn: conn, survey_token: survey_token} do
      {:ok, view, _html} = live(conn, ~p"/survey/#{survey_token.token}")

      # Complete the survey
      html = render_click(view, "complete_survey")

      assert html =~ "Survey Completed!"
      assert html =~ "Thank you for participating"
      assert html =~ "Your responses have been recorded"
    end

    test "shows participant information correctly", %{conn: conn, survey_token: survey_token} do
      {:ok, _view, html} = live(conn, ~p"/survey/#{survey_token.token}")

      # Check that participant info is displayed
      assert html =~ "Participant Information"
      assert html =~ survey_token.age |> to_string()

      gender_display = if survey_token.gender == "M", do: "Male", else: "Female"
      assert html =~ gender_display

      assert html =~ Calendar.strftime(survey_token.birth_date, "%d/%m/%Y")
      assert html =~ survey_token.birth_place_code
    end

    test "prevents access to already used token", %{conn: conn, survey_token: survey_token} do
      # First, use the token
      {:ok, _used_token} = Surveys.use_survey_token(survey_token.token)

      # Try to access again
      {:ok, _view, html} = live(conn, ~p"/survey/#{survey_token.token}")

      assert html =~ "Access Denied"
      assert html =~ "Invalid or expired token"
    end

    test "shows token expiration information", %{conn: conn, survey_token: survey_token} do
      {:ok, _view, html} = live(conn, ~p"/survey/#{survey_token.token}")

      assert html =~ "Token expires:"
      assert html =~ "Token valid"
      assert html =~ Calendar.strftime(survey_token.expires_at, "%B %d, %Y")
    end
  end

  describe "User Workflow" do
    test "complete workflow: authenticated user generates token, unregistered user takes survey",
         %{
           conn: conn
         } do
      # Step 1: Authenticated user generates token
      user = user_fixture()
      authenticated_conn = log_in_user(conn, user)

      {:ok, view, _html} = live(authenticated_conn, ~p"/token")

      # Generate token
      html =
        view
        |> form("form", %{"ic_number" => "501007081234"})
        |> render_submit()

      assert html =~ "Survey Token Generated Successfully"

      # Extract token from the response - look for the survey URL in the HTML
      token_regex = ~r/\/survey\/([a-zA-Z0-9_-]+)/
      [_, token_url] = Regex.run(token_regex, html)

      # Step 2: Unregistered user (new conn without authentication) accesses survey
      unauth_conn = build_conn()
      {:ok, survey_view, survey_html} = live(unauth_conn, ~p"/survey/#{token_url}")

      assert survey_html =~ "Health Survey"
      assert survey_html =~ "Participant Information"

      # Step 3: Unregistered user completes survey
      completion_html = render_click(survey_view, "complete_survey")
      assert completion_html =~ "Survey Completed!"
    end

    test "token link works across different sessions", %{conn: conn} do
      # User generates token in one session
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/token")

      html =
        view
        |> form("form", %{"ic_number" => "501007081234"})
        |> render_submit()

      [_, token_url] = Regex.run(~r/\/survey\/([a-zA-Z0-9_-]+)/, html)

      # Completely new connection (simulating link sharing)
      new_conn = build_conn()
      {:ok, _view, survey_html} = live(new_conn, ~p"/survey/#{token_url}")

      assert survey_html =~ "Health Survey"
      assert survey_html =~ "Participant Information"
    end
  end

  describe "Authentication Error Messages" do
    test "shows appropriate error message for unauthenticated user trying to generate token", %{
      conn: conn
    } do
      conn = get(conn, ~p"/token")
      assert redirected_to(conn) == "/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "log in to access"
    end

    test "token generation page shows correct authentication message", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _view, html} = live(conn, ~p"/token")

      assert html =~ "User Authentication Required"
      assert html =~ "You must be logged in to generate survey tokens for others"
    end
  end

  describe "Reset Functionality" do
    test "authenticated user can reset form", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/token")

      # Enter some data
      view
      |> form("form", %{"ic_number" => "501007081234"})
      |> render_change()

      # Reset the form
      html = render_click(view, "reset")

      # Form should be cleared
      assert html =~ ~s(value="")
      refute html =~ "IC Information Preview"
      refute html =~ "Survey Token Generated Successfully"
    end
  end
end
