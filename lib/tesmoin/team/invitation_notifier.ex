defmodule Tesmoin.Team.InvitationNotifier do
  import Swoosh.Email

  alias Tesmoin.Mailer

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
  Sends an invitation email with an accept link.
  """
  def deliver_invitation(invitation, accept_url) do
    days = Tesmoin.Team.MemberInvitation.token_validity_days()

    inviter =
      if invitation.invited_by do
        invitation.invited_by.email
      else
        "a Tesmoin administrator"
      end

    deliver(invitation.email, "You've been invited to Tesmoin", """

    ==============================

    Hi #{invitation.email},

    #{inviter} has invited you to join this Tesmoin node as #{invitation.role}.

    Accept your invitation by visiting the link below:

    #{accept_url}

    This invitation is valid for #{days} days. If you did not expect this email, you can safely ignore it.

    ==============================
    """)
  end
end
