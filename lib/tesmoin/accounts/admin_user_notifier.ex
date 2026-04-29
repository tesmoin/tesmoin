defmodule Tesmoin.Accounts.AdminUserNotifier do
  import Swoosh.Email

  alias Tesmoin.Mailer
  alias Tesmoin.Accounts.AdminUser

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Tesmoin", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a admin_user email.
  """
  def deliver_update_email_instructions(admin_user, url) do
    deliver(admin_user.email, "Update email instructions", """

    ==============================

    Hi #{admin_user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(admin_user, url) do
    case admin_user do
      %AdminUser{confirmed_at: nil} -> deliver_confirmation_instructions(admin_user, url)
      _ -> deliver_magic_link_instructions(admin_user, url)
    end
  end

  defp deliver_magic_link_instructions(admin_user, url) do
    deliver(admin_user.email, "Log in instructions", """

    ==============================

    Hi #{admin_user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(admin_user, url) do
    deliver(admin_user.email, "Confirmation instructions", """

    ==============================

    Hi #{admin_user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
