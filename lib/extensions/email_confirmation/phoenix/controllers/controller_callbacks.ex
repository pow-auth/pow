defmodule PowEmailConfirmation.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.{Phoenix.Controller, Plug}
  alias PowEmailConfirmation.Phoenix.{ConfirmationController, Mailer}

  def before_process(Pow.Phoenix.RegistrationController, :update, conn, _config) do
    user = Plug.current_user(conn)

    Conn.put_private(conn, :pow_user_before_update, user)
  end

  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, user, conn}, _config) do
    reject_unconfirmed(user, conn)
  end
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    reject_unconfirmed(user, conn)
  end
  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, _config) do
    case should_send_email?(user, conn.private[:pow_user_before_update]) do
      true  ->
        send_confirmation_email(user, conn)

        {:ok, user, conn}

      false ->
        {:ok, user, conn}
    end
  end

  defp should_send_email?(%{unconfirmed_email: new_email}, %{unconfirmed_email: old_email}),
    do: new_email != old_email

  defp reject_unconfirmed(%{email_confirmed_at: nil, email_confirmation_token: token} = user, conn) when not is_nil(token) do
    send_confirmation_email(user, conn)

    reject(conn)
  end
  defp reject_unconfirmed(user, conn), do: {:ok, user, conn}

  defp reject(conn) do
    {:ok, conn} = Plug.clear_authenticated_user(conn)
    error       = ConfirmationController.messages(conn).email_confirmation_required(conn)
    path        = Controller.router_helpers(conn).pow_session_path(conn, :new)
    conn        =
      conn
      |> Phoenix.Controller.put_flash(:error, error)
      |> Phoenix.Controller.redirect(to: path)

    {:halt, conn}
  end

  @spec send_confirmation_email(map(), Conn.t()) :: any()
  def send_confirmation_email(user, conn) do
    token = user.email_confirmation_token
    url   = Controller.router_helpers(conn).pow_email_confirmation_confirmation_url(conn, :show, token)
    email = Mailer.email_confirmation(conn, user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end
end
