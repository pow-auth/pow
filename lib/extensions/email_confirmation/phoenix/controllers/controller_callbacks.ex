defmodule PowEmailConfirmation.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.{Phoenix.Controller, Plug}
  alias PowEmailConfirmation.Phoenix.Mailer

  def before_process(Pow.Phoenix.RegistrationController, :update, conn, _config) do
    user = Plug.current_user(conn)

    Conn.put_private(conn, :pow_user_before_update, user)
  end

  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    send_confirmation_email(user, conn)

    {:ok, user, conn}
  end
  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, _config) do
    maybe_send_confirmation_email(user, conn)

    {:ok, user, conn}
  end

  defp maybe_send_confirmation_email(user, conn) do
    case should_send_email?(user, conn.private[:pow_user_before_update]) do
      true  -> send_confirmation_email(user, conn)
      false -> {:ok, user, conn}
    end
  end

  defp should_send_email?(_user, nil), do: false
  defp should_send_email?(%{email_confirmed_at: confirmed_at}, _user) when not is_nil(confirmed_at), do: false
  defp should_send_email?(%{email_confirmed_at: nil, email_confirmation_token: new_token}, %{email_confirmation_token: old_token}),
    do: new_token != old_token

  @spec send_confirmation_email(map(), Conn.t()) :: {:ok, map(), Conn.t()}
  def send_confirmation_email(user, conn) do
    token = user.email_confirmation_token
    url   = Controller.router_helpers(conn).pow_email_confirmation_confirmation_url(conn, :show, token)
    email = Mailer.email_confirmation(conn, user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)

    {:ok, user, conn}
  end
end
