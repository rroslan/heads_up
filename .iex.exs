alias HeadsUp.Accounts
alias HeadsUp.Repo
alias HeadsUp.Accounts.User

defmodule UserHelpers do
  @moduledoc """
  Convenience functions for user management in IEx.
  """
  alias HeadsUp.Accounts

  def register_user(email) when is_binary(email) do
    IO.puts("Attempting to register user: #{email}")

    case Accounts.register_user(%{"email" => email}) do
      {:ok, user} -> IO.inspect({:ok, user})
      {:error, changeset} -> IO.inspect({:error, changeset})
    end
  end
end

import UserHelpers
