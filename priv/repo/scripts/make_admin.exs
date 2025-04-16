#!/usr/bin/env elixir

# Script to set is_admin=true for a user with the email from ADMIN_EMAIL
# Usage: mix run priv/repo/scripts/make_admin.exs

require Logger
import Ecto.Query
alias HeadsUp.Repo
alias HeadsUp.Accounts.User

# Get the admin email from environment variable
admin_email = System.get_env("ADMIN_EMAIL") || raise "ADMIN_EMAIL environment variable is not set"

Logger.info("Setting admin status for user with email: #{admin_email}")

# Check if the is_admin column exists in the users table
is_admin_exists = try do
  result = Repo.query!("SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'is_admin'")
  count = result.num_rows
  count > 0
rescue
  e ->
    Logger.error("Error checking is_admin column: #{inspect(e)}")
    false
end

if is_admin_exists do
  # Find the user with the given email
  case Repo.get_by(User, email: admin_email) do
    %User{} = user ->
      # Update the is_admin field to true
      result = Repo.update_all(
        from(u in "users", where: u.id == ^user.id),
        set: [is_admin: true]
      )
      
      case result do
        {1, nil} ->
          Logger.info("Successfully set is_admin=true for user #{admin_email}")
        {0, nil} ->
          Logger.error("No updates were made. User might already be an admin.")
        _ ->
          Logger.error("Unexpected result: #{inspect(result)}")
      end
      
    nil ->
      Logger.error("No user found with email: #{admin_email}")
  end
else
  Logger.error("The is_admin column does not exist in the users table.")
  Logger.info("You may need to run a migration to add this column.")
end

