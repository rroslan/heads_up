defmodule HeadsUp.Accounts.UserNotifier do
  import Swoosh.Email

  alias HeadsUp.Mailer
  alias HeadsUp.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, text_body, html_body) do
    email =
      new()
      |> to(recipient)
      |> from({"HeadsUp", "noreply@applikasi.tech"})
      |> subject(subject)
      |> text_body(text_body)
      |> html_body(html_body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    text_body = """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """
    
    html_body = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body {
          font-family: Arial, sans-serif;
          color: #333;
          line-height: 1.6;
          margin: 0;
          padding: 0;
          background-color: #f9f9f9;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #ffffff;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        .header {
          text-align: center;
          padding: 20px 0;
          border-bottom: 1px solid #eee;
        }
        .header h1 {
          color: #4F46E5;
          margin: 0;
          font-size: 24px;
        }
        .content {
          padding: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4F46E5;
          color: white;
          text-decoration: none;
          padding: 10px 20px;
          border-radius: 4px;
          margin: 20px 0;
          font-weight: bold;
        }
        .footer {
          text-align: center;
          padding: 20px 0;
          color: #666;
          font-size: 14px;
          border-top: 1px solid #eee;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>HeadsUp</h1>
        </div>
        <div class="content">
          <p>Hi #{user.email},</p>
          <p>You can change your email by clicking the button below:</p>
          <p>
            <a href="#{url}" class="button">Update Email</a>
          </p>
          <p>Or copy and paste this URL into your browser:</p>
          <p><a href="#{url}">#{url}</a></p>
          <p>If you didn't request this change, please ignore this email.</p>
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} HeadsUp. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
    
    deliver(user.email, "Update email instructions", text_body, html_body)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  If the user is unconfirmed, deliver confirmation instructions instead.
  """
  def deliver_login_instructions(%User{confirmed_at: nil} = user, url) do
    deliver_confirmation_instructions(user, url)
  end

  def deliver_login_instructions(user, url) do
    deliver_magic_link_instructions(user, url)
  end

  defp deliver_magic_link_instructions(user, url) do
    text_body = """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """
    
    html_body = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body {
          font-family: Arial, sans-serif;
          color: #333;
          line-height: 1.6;
          margin: 0;
          padding: 0;
          background-color: #f9f9f9;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #ffffff;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        .header {
          text-align: center;
          padding: 20px 0;
          border-bottom: 1px solid #eee;
        }
        .header h1 {
          color: #4F46E5;
          margin: 0;
          font-size: 24px;
        }
        .content {
          padding: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4F46E5;
          color: white;
          text-decoration: none;
          padding: 10px 20px;
          border-radius: 4px;
          margin: 20px 0;
          font-weight: bold;
        }
        .footer {
          text-align: center;
          padding: 20px 0;
          color: #666;
          font-size: 14px;
          border-top: 1px solid #eee;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>HeadsUp</h1>
        </div>
        <div class="content">
          <p>Hi #{user.email},</p>
          <p>You can log into your account by clicking the button below:</p>
          <p>
            <a href="#{url}" class="button">Log In</a>
          </p>
          <p>Or copy and paste this URL into your browser:</p>
          <p><a href="#{url}">#{url}</a></p>
          <p>If you didn't request this email, please ignore it.</p>
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} HeadsUp. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
    
    deliver(user.email, "Log in instructions", text_body, html_body)
  end
  defp deliver_confirmation_instructions(user, url) do
    text_body = """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """
    
    html_body = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body {
          font-family: Arial, sans-serif;
          color: #333;
          line-height: 1.6;
          margin: 0;
          padding: 0;
          background-color: #f9f9f9;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #ffffff;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        .header {
          text-align: center;
          padding: 20px 0;
          border-bottom: 1px solid #eee;
        }
        .header h1 {
          color: #4F46E5;
          margin: 0;
          font-size: 24px;
        }
        .content {
          padding: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4F46E5;
          color: white;
          text-decoration: none;
          padding: 10px 20px;
          border-radius: 4px;
          margin: 20px 0;
          font-weight: bold;
        }
        .footer {
          text-align: center;
          padding: 20px 0;
          color: #666;
          font-size: 14px;
          border-top: 1px solid #eee;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>HeadsUp</h1>
        </div>
        <div class="content">
          <p>Hi #{user.email},</p>
          <p>Welcome to HeadsUp! Please confirm your account by clicking the button below:</p>
          <p>
            <a href="#{url}" class="button">Confirm Account</a>
          </p>
          <p>Or copy and paste this URL into your browser:</p>
          <p><a href="#{url}">#{url}</a></p>
          <p>If you didn't create an account with us, please ignore this email.</p>
        </div>
        <div class="footer">
          <p>&copy; #{DateTime.utc_now().year} HeadsUp. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
    """
    
    deliver(user.email, "Confirmation instructions", text_body, html_body)
  end
end
