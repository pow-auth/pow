defmodule PowEmailConfirmation.Phoenix.Base do

  use Pow.Extension.Phoenix.Controller.Base

  alias PowEmailConfirmation.Phoenix.ConfirmationController
  alias PowEmailConfirmation.Phoenix.Mailer
  alias PowEmailConfirmation.Plug

  def send_confirmation_email(conn) do
    user = Plug.refreshed_user_with_confirmation_token(conn)
    url = confirmation_url(conn, user.email_confirmation_token)
    unconfirmed_user = %{user | email: user.unconfirmed_email || user.email}
    email = Mailer.email_confirmation(conn, unconfirmed_user, url)
    Pow.Phoenix.Mailer.deliver(conn, email)

    conn
  end

  defp confirmation_url(conn, token) do
    routes(conn).url_for(conn, ConfirmationController, :show, [token])
  end
end