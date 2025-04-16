defmodule HeadsUpWeb.Plugs.EnsureAdmin do
  @moduledoc """
  This plug ensures that a user is an admin.

  ## Examples

      import HeadsUpWeb.Plugs.EnsureAdmin

      # Use it in a pipeline
      pipeline :admin_only do
        plug :ensure_admin
      end

      # Use it in a scope
      scope "/admin", HeadsUpWeb do
        pipe_through [:browser, :require_authenticated_user, :ensure_admin]
        
        # Admin-only routes
      end
  """
  import Plug.Conn
  import Phoenix.Controller

  @doc """
  Ensures the user is an admin.
  """
  def ensure_admin(conn, _opts) do
    # Check for current_user first, then fall back to current_scope
    user = get_user_from_conn(conn)

    case is_admin?(user) do
      true -> conn
      false ->
        conn
        |> put_flash(:error, "You must be an administrator to access this page.")
        |> redirect(to: "/")
        |> halt()
    end
  end

  @doc """
  Callback for LiveView on_mount to check admin access.
  """
  def on_mount(:ensure_admin, _params, _session, socket) do
    current_user = get_user_from_socket(socket)

    if is_admin?(current_user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be an administrator to access this page.")
        |> Phoenix.LiveView.redirect(to: "/")

      {:halt, socket}
    end
  end

  # Get user from conn assigns, checking both current_user and current_scope
  defp get_user_from_conn(conn) do
    cond do
      # Check direct current_user first
      Map.has_key?(conn.assigns, :current_user) && conn.assigns.current_user != nil ->
        conn.assigns.current_user
      
      # Fall back to current_scope if needed
      Map.has_key?(conn.assigns, :current_scope) && 
      conn.assigns.current_scope && 
      Map.has_key?(conn.assigns.current_scope, :user) ->
        conn.assigns.current_scope.user
        
      true -> nil
    end
  end

  # Get user from socket assigns, checking both current_user and current_scope
  defp get_user_from_socket(socket) do
    cond do
      # Check direct current_user first
      Map.has_key?(socket.assigns, :current_user) && socket.assigns.current_user != nil ->
        socket.assigns.current_user
      
      # Fall back to current_scope if needed
      Map.has_key?(socket.assigns, :current_scope) && 
      socket.assigns.current_scope && 
      Map.has_key?(socket.assigns.current_scope, :user) ->
        socket.assigns.current_scope.user
        
      true -> nil
    end
  end

  defp is_admin?(user) when is_map(user), do: Map.get(user, :is_admin, false)
  defp is_admin?(_), do: false
end

