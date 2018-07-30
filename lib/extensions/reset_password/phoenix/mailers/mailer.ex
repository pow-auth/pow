defmodule PowResetPassword.Phoenix.Mailer do
  @moduledoc false
  alias Plug.Conn
  alias Pow.Phoenix.Mailer.Mail
  alias PowResetPassword.Phoenix.MailerView

  @spec reset_password(Conn.t(), map(), binary()) :: Mail.t()
  def reset_password(conn, user, url) do
    Mail.new(conn, user, {MailerView, :reset_password}, url: url)
  end
end
