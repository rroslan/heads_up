defmodule HeadsUpWeb.PageControllerTest do
  use HeadsUpWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Welcome to HeadsUp"
  end
end
