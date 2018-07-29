defmodule PowEmailConfirmation.Phoenix.Mailer.EmailConfirmationMailer do
  @moduledoc false
  alias Pow.Phoenix.Mailer.Mail
  alias PowEmailConfirmation.Phoenix.Mailer.EmailConfirmationView

  @spec email_confirmation(map(), binary()) :: Mail.t()
  def email_confirmation(user, url) do
    subject = EmailConfirmationView.subject(:mail)
    text = EmailConfirmationView.render("mail.text", url: url)
    html = EmailConfirmationView.render("mail.html", url: url)

    Mail.new(user, subject, text, html)
  end
end
