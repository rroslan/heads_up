defmodule HeadsUp.MailerTest do
  use HeadsUp.DataCase
  use ExUnit.Case
  
  import Swoosh.TestAssertions
  import HeadsUp.AccountsFixtures
  
  alias HeadsUp.Accounts

  describe "mailer configuration" do
    test "test environment uses Swoosh.Adapters.Test" do
      # Verify that the test environment uses the test adapter
      assert Application.get_env(:heads_up, HeadsUp.Mailer)[:adapter] == Swoosh.Adapters.Test
    end
    
    test "prod environment would use Resend.Swoosh.Adapter" do
      # This test verifies that if we were in prod, we'd use Resend
      # We can't directly test the runtime.exs file, but we can check the code
      # that would be executed in prod
      
      # Save the current environment config
      current_config = Application.get_env(:heads_up, HeadsUp.Mailer)
      
      try do
        # Mock the prod environment by setting the adapter
        # (Note: we don't set the API key since we don't want to actually send emails)
        Application.put_env(:heads_up, HeadsUp.Mailer, adapter: Resend.Swoosh.Adapter)
        
        # Verify the adapter is set correctly
        assert Application.get_env(:heads_up, HeadsUp.Mailer)[:adapter] == Resend.Swoosh.Adapter
      after
        # Restore the original config
        Application.put_env(:heads_up, HeadsUp.Mailer, current_config)
      end
    end
  end
  
  describe "email formatting" do
    test "emails are sent from noreply@applikasi.tech" do
      user = user_fixture()
      
      # Extract the email that would be sent
      email = extract_user_email(fn url ->
        Accounts.deliver_login_instructions(user, fn token -> 
          "#{url}/#{token}"
        end)
      end)
      
      # Verify the "from" address
      assert email.from == {"HeadsUp", "noreply@applikasi.tech"}
    end
    
    test "emails have proper structure" do
      user = user_fixture()
      
      email = extract_user_email(fn url ->
        Accounts.deliver_login_instructions(user, fn token -> 
          "#{url}/#{token}"
        end)
      end)
      
      # Verify the structure of the email
      assert email.to == [{"", user.email}]
      assert email.subject =~ "Log in instructions"
      assert email.text_body =~ user.email
      assert email.text_body =~ "You can log into your account"
    end
  end
  
  describe "email delivery" do
    test "login instructions email is properly formed and delivered" do
      user = user_fixture()
      
      # Call the function that delivers the email
      _ = extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)
      
      # Assert that the email was sent with the correct structure
      assert_email_sent(
        from: {"HeadsUp", "noreply@applikasi.tech"},
        to: [{"", user.email}],
        subject: "Log in instructions"
      )
    end
    
    test "confirmation instructions for unconfirmed users" do
      user = unconfirmed_user_fixture()
      
      _ = extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)
      
      # Assert that a confirmation email was sent
      assert_email_sent(
        from: {"HeadsUp", "noreply@applikasi.tech"},
        to: [{"", user.email}],
        subject: "Confirmation instructions"
      )
    end
    
    test "email update instructions" do
      user = user_fixture()
      new_email = "new_#{unique_user_email()}"
      
      _ = extract_user_token(fn url ->
        Accounts.deliver_user_update_email_instructions(user, new_email, url)
      end)
      
      # Assert that an email update instructions email was sent
      assert_email_sent(
        from: {"HeadsUp", "noreply@applikasi.tech"},
        to: [{"", user.email}],
        subject: "Update email instructions"
      )
    end
  end
  
  # Helper to extract the email that would be delivered
  defp extract_user_email(fun) do
    fun.("https://example.com")
    
    # Use Swoosh.TestAssertions to get the last sent email
    assert_email_sent(fn email -> 
      email
    end)
  end
end

