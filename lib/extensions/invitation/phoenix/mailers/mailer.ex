defmodule PowInvitation.Phoenix.Mailer do
  @moduledoc false
  alias Plug.Conn
  alias Pow.Phoenix.Mailer.Mail
  alias PowInvitation.Phoenix.MailerView

  @spec invitation(Conn.t(), map(), map(), binary()) :: Mail.t()
  def invitation(conn, user, invited_by, url) do
    invited_by_user_id = Map.get(invited_by, invited_by.__struct__.pow_user_id_field())

    Mail.new(conn, user, {MailerView, :invitation}, invited_by: invited_by, invited_by_user_id: invited_by_user_id, url: url)
  end
end
