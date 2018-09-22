defmodule PowEmailConfirmation.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.{Phoenix.Controller, Phoenix.SessionController, Plug}
  alias PowEmailConfirmation.Phoenix.{ConfirmationController, Mailer}

  def before_process(Pow.Phoenix.RegistrationController, :update, conn, _config) do
    user = Plug.current_user(conn)

    Conn.put_private(conn, :pow_user_before_update, user)
  end

  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    conn
    |> Plug.current_user()
    |> halt_unconfirmed(conn, {:ok, conn})
  end
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    halt_unconfirmed(user, conn, {:ok, user, conn})
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

  defp halt_unconfirmed(%{email_confirmed_at: nil, email_confirmation_token: token} = user, conn, _success_response) when not is_nil(token) do
    send_confirmation_email(user, conn)

    {:ok, conn} = Plug.clear_authenticated_user(conn)
    error       = ConfirmationController.messages(conn).email_confirmation_required(conn)
    path        = Controller.router_path(conn, SessionController, :new)
    conn        =
      conn
      |> Phoenix.Controller.put_flash(:error, error)
      |> Phoenix.Controller.redirect(to: path)

    {:halt, conn}
  end
  defp halt_unconfirmed(_user, _conn, success_response), do: success_response

  @spec send_confirmation_email(map(), Conn.t()) :: any()
  def send_confirmation_email(user, conn) do
    token = user.email_confirmation_token
    url   = Controller.router_url(conn, ConfirmationController, :show, [token])
    email = Mailer.email_confirmation(conn, user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end
end
