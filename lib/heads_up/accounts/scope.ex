defmodule HeadsUp.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `HeadsUp.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias HeadsUp.Accounts.User

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Checks if the scope represents an admin user.
  """
  def admin?(%__MODULE__{user: %User{is_admin: true}}), do: true
  def admin?(_), do: false

  @doc """
  Checks if the scope represents an editor user.
  """
  def editor?(%__MODULE__{user: %User{is_editor: true}}), do: true
  def editor?(_), do: false

  @doc """
  Checks if the scope represents a user with editor or admin privileges.
  """
  def can_edit?(%__MODULE__{user: %User{is_admin: true}}), do: true
  def can_edit?(%__MODULE__{user: %User{is_editor: true}}), do: true
  def can_edit?(_), do: false

  @doc """
  Checks if the scope represents an authenticated user.
  """
  def authenticated?(%__MODULE__{user: %User{}}), do: true
  def authenticated?(_), do: false
end
