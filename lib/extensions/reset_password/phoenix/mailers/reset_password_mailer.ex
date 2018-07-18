defmodule AuthexResetPassword.Phoenix.Mailer.ResetPasswordMailer do
  alias Authex.Phoenix.Mailer.Mail
  alias AuthexResetPassword.Phoenix.Mailer.ResetPasswordView

  @spec reset_password(map(), binary()) :: Mail.t()
  def reset_password(user, url) do
    subject = ResetPasswordView.subject(:mail)
    text = ResetPasswordView.render("mail.text", url: url)
    html = ResetPasswordView.render("mail.html", url: url)

    Mail.new(user, subject, html, text)
  end
end
