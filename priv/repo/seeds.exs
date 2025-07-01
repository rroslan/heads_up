# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     HeadsUp.Repo.insert!(%HeadsUp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias HeadsUp.Accounts

# Create admin user for development/testing
admin_email = "rroslan@gmail.com"

case Accounts.get_user_by_email(admin_email) do
  nil ->
    {:ok, admin} =
      Accounts.register_user(%{
        email: admin_email,
        is_admin: true,
        is_editor: false
      })

    IO.puts("Created admin user: #{admin.email}")
    IO.puts("Use magic link login to access the admin interface")

  _user ->
    IO.puts("Admin user already exists: #{admin_email}")
end

# Create sample editor user
editor_email = "roslanr@gmail.com"

case Accounts.get_user_by_email(editor_email) do
  nil ->
    {:ok, editor} =
      Accounts.register_user(%{
        email: editor_email,
        is_admin: false,
        is_editor: true
      })

    IO.puts("Created editor user: #{editor.email}")

  _user ->
    IO.puts("Editor user already exists: #{editor_email}")
end

# Create sample regular user
user_email = "dev.rroslan@gmail.com"

case Accounts.get_user_by_email(user_email) do
  nil ->
    {:ok, user} =
      Accounts.register_user(%{
        email: user_email,
        is_admin: false,
        is_editor: false
      })

    IO.puts("Created regular user: #{user.email}")

  _user ->
    IO.puts("Regular user already exists: #{user_email}")
end

IO.puts("\nTo login:")
IO.puts("1. Visit http://localhost:4000/users/log-in")
IO.puts("2. Enter one of the email addresses above")
IO.puts("3. Check your logs for the magic link (in development)")
IO.puts("4. Admin users can access user management at /users")
