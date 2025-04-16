#!/usr/bin/env elixir

# Script to create an admin user using environment variables
# Usage: mix run priv/repo/scripts/create_admin_user.exs

require Logger
import Ecto.Query
alias HeadsUp.Repo
alias HeadsUp.Accounts.User

# Get environment variables
admin_email = System.get_env("ADMIN_EMAIL") || raise "ADMIN_EMAIL environment variable is not set"
admin_password = System.get_env("ADMIN_PASSWORD") || raise "ADMIN_PASSWORD environment variable is not set"

Logger.info("Creating admin user with email: #{admin_email}")

# Check if user already exists
case Repo.get_by(User, email: admin_email) do
  %User{} = user ->
    Logger.info("Admin user already exists with email: #{admin_email}")
    
    # Check if is_admin field exists in the schema
    is_admin_field = Map.has_key?(user, :is_admin)
    
    # Update to admin if not already
    if is_admin_field && !user.is_admin do
      Repo.update_all(
        from(u in User, where: u.id == ^user.id),
        set: [is_admin: true]
      )
      Logger.info("Updated user to admin status")
    end

  nil ->
    # Create new user with admin privileges
    user_params = %{
      email: admin_email,
      password: admin_password,
      password_confirmation: admin_password
    }

    # Step 1: Create the user
    user_changeset = 
      %User{}
      |> User.email_changeset(user_params)
      |> User.password_changeset(user_params)
      
    case Repo.insert(user_changeset) do
      {:ok, user} ->
        Logger.info("Created new user with email: #{admin_email}")
        
        # Step 3: Set as admin using direct SQL since is_admin might not be in the changeset
        # Check if the is_admin field exists in the users table by executing a query
        is_admin_exists = try do
          Repo.query!("SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'is_admin'")
          |> Map.get(:num_rows) > 0
        rescue
          _ -> false
        end
        
        if is_admin_exists do
          Repo.update_all(
            from(u in User, where: u.id == ^confirmed_user.id),
            set: [is_admin: true]
          )
          Logger.info("User set as admin")
        else
          Logger.warn("Could not set admin status: is_admin field doesn't exist in users table")
        end
        # Step 3: Set as admin using direct SQL since is_admin might not be in the changeset
        Repo.update_all(
          from(u in User, where: u.id == ^confirmed_user.id),
          set: [is_admin: true]
        )
        Logger.info("User set as admin")
        
        Logger.info("Admin user successfully created and configured!")
        
      {:error, changeset} ->
        Logger.error("Failed to create admin user")
        IO.inspect(changeset.errors, label: "Errors")
    end
end

