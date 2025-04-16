defmodule HeadsUp.Accounts do
  @moduledoc """
  The Accounts context.
  
  This context handles all user management, authentication, and authorization
  operations including admin functions for user management.
  """

  import Ecto.Query, warn: false
  alias HeadsUp.Repo

  alias HeadsUp.Accounts.{User, UserToken, UserNotifier}

  @type pagination :: %{page: integer, per_page: integer}
  @type user_stats :: %{
    total_users: integer, 
    active_users: integer, 
    admin_users: integer, 
    unconfirmed_users: integer
  }

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `HeadsUp.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset = User.email_changeset(user, %{email: email})

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `HeadsUp.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, %User{}, [...]}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
    |> case do
      {:ok, user, expired_tokens} -> {:ok, user, expired_tokens}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, user, []}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc ~S"""
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    %{data: %User{} = user} = changeset

    with {:ok, %{user: user, tokens_to_expire: expired_tokens}} <-
           Ecto.Multi.new()
           |> Ecto.Multi.update(:user, changeset)
           |> Ecto.Multi.all(:tokens_to_expire, UserToken.by_user_and_contexts_query(user, :all))
           |> Ecto.Multi.delete_all(:tokens, fn %{tokens_to_expire: tokens_to_expire} ->
             UserToken.delete_all_query(tokens_to_expire)
           end)
           |> Repo.transaction() do
      {:ok, user, expired_tokens}
    end
  end

  ## Admin functions

  @doc """
  Returns a paginated list of users.

  ## Options

  * `:page` - The page number (default: 1)
  * `:per_page` - Number of users per page (default: 20)
  * `:sort_by` - Field to sort by (default: :inserted_at)
  * `:sort_direction` - Sort direction (:asc or :desc, default: :desc)
  * `:filter` - Optional filter criteria (e.g., %{is_admin: true})

  ## Examples

      iex> list_users()
      [%User{}, ...]

      iex> list_users(%{page: 2, per_page: 10})
      [%User{}, ...]

      iex> list_users(%{filter: %{is_admin: true}})
      [%User{is_admin: true}, ...]

  """
  @spec list_users(map()) :: {[User.t()], map()}
  def list_users(opts \\ %{}) do
    page = Map.get(opts, :page, 1)
    per_page = Map.get(opts, :per_page, 20)
    sort_by = Map.get(opts, :sort_by, :inserted_at)
    sort_direction = Map.get(opts, :sort_direction, :desc)
    filter = Map.get(opts, :filter, %{})

    query = from(u in User)

    query =
      Enum.reduce(filter, query, fn
        {:is_admin, value}, query ->
          from(u in query, where: u.is_admin == ^value)

        {:confirmed, value}, query ->
          case value do
            true -> from(u in query, where: not is_nil(u.confirmed_at))
            false -> from(u in query, where: is_nil(u.confirmed_at))
            _ -> query
          end

        {:search, term}, query when is_binary(term) and term != "" ->
          term = "%#{term}%"
          from(u in query, where: ilike(u.email, ^term))

        _, query ->
          query
      end)

    # Get total count before pagination
    total_count = Repo.aggregate(query, :count, :id)

    # Apply sorting and pagination
    query =
      from(u in query,
        order_by: [{^sort_direction, ^sort_by}],
        offset: ^((page - 1) * per_page),
        limit: ^per_page
      )

    users = Repo.all(query)

    {users,
     %{
       page: page,
       per_page: per_page,
       total_count: total_count,
       total_pages: ceil(total_count / per_page)
     }}
  end

  @doc """
  Gets statistics about users in the system.

  Returns a map with:
  * `:total_users` - Total number of users
  * `:active_users` - Users who have authenticated in the last 30 days
  * `:admin_users` - Number of users with admin privileges
  * `:unconfirmed_users` - Users who haven't confirmed their accounts

  ## Examples

      iex> get_user_stats()
      %{
        total_users: 100,
        active_users: 42,
        admin_users: 5,
        unconfirmed_users: 10
      }

  """
  @spec get_user_stats() :: user_stats()
  def get_user_stats do
    # Total users
    total_users = Repo.aggregate(User, :count, :id)

    # Users with admin privileges
    admin_query = from(u in User, where: u.is_admin == true)
    admin_users = Repo.aggregate(admin_query, :count, :id)

    # Unconfirmed users
    unconfirmed_query = from(u in User, where: is_nil(u.confirmed_at))
    unconfirmed_users = Repo.aggregate(unconfirmed_query, :count, :id)

    # Active users in the last 30 days
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30, :day)

    # Use a subquery to count unique user_ids to avoid the GROUP BY issue
    active_query =
      from(u in User,
        join: t in UserToken,
        on: t.user_id == u.id,
        where: t.context == "session" and t.inserted_at > ^thirty_days_ago,
        distinct: u.id,
        select: count(u.id)
      )

    active_users = Repo.one(active_query) || 0

    %{
      total_users: total_users,
      active_users: active_users,
      admin_users: admin_users,
      unconfirmed_users: unconfirmed_users
    }
  end

  @doc """
  Sets the admin status for a user.

  This function should only be called by admin users or system processes.
  It allows toggling the admin status of a user account.

  ## Examples

      iex> set_admin_status(user, true)
      {:ok, %User{is_admin: true}}

      iex> set_admin_status(user, false)
      {:ok, %User{is_admin: false}}

  """
  @spec set_admin_status(User.t(), boolean()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def set_admin_status(%User{} = user, is_admin) when is_boolean(is_admin) do
    user
    |> User.admin_changeset(is_admin)
    |> Repo.update()
  end

  @doc """
  Gets activity information for a user.

  Returns a map with:
  * `:last_login` - Timestamp of the user's most recent login
  * `:login_count` - Number of times the user has logged in
  * `:created_at` - When the user was created
  * `:confirmed_at` - When the user confirmed their account (if applicable)

  ## Examples

      iex> get_user_activity(user)
      %{
        last_login: ~U[2023-01-01 00:00:00Z],
        login_count: 5,
        created_at: ~U[2022-01-01 00:00:00Z],
        confirmed_at: ~U[2022-01-02 00:00:00Z]
      }

  """
  @spec get_user_activity(User.t()) :: map()
  def get_user_activity(%User{} = user) do
    # Get the most recent session token
    last_session_query =
      from(t in UserToken,
        where: t.user_id == ^user.id and t.context == "session",
        order_by: [desc: t.inserted_at],
        limit: 1,
        select: t.inserted_at
      )

    last_login = Repo.one(last_session_query)

    # Count the number of logins
    login_count_query =
      from(t in UserToken,
        where: t.user_id == ^user.id and t.context == "login",
        select: count(t.id)
      )

    login_count = Repo.one(login_count_query) || 0

    %{
      last_login: last_login,
      login_count: login_count,
      created_at: user.inserted_at,
      confirmed_at: user.confirmed_at
    }
  end

  @doc """
  Returns a list of the most recently registered users.

  ## Options

  * `:limit` - Maximum number of users to return (default: 5)

  ## Examples

      iex> list_recent_users()
      [%User{}, ...]

      iex> list_recent_users(10)
      [%User{}, ...]

  """
  @spec list_recent_users(integer()) :: [User.t()]
  def list_recent_users(limit \\ 5) do
    query =
      from(u in User,
        order_by: [desc: u.inserted_at],
        limit: ^limit
      )

    Repo.all(query)
  end
end
