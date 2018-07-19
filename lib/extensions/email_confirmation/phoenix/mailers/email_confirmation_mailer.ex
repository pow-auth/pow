defmodule AuthexEmailConfirmation.Phoenix.Mailer.EmailConfirmationMailer do
  alias Authex.Phoenix.Mailer.Mail
  alias AuthexEmailConfirmation.Phoenix.Mailer.EmailConfirmationView

  @spec email_confirmation(map(), binary()) :: Mail.t()
  def email_confirmation(user, url) do
    subject = EmailConfirmationView.subject(:mail)
    text = EmailConfirmationView.render("mail.text", url: url)
    html = EmailConfirmationView.render("mail.html", url: url)

    Mail.new(user, subject, html, text)
  end
end
