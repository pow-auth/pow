defmodule PowEmailConfirmation.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.Plug
  alias PowEmailConfirmation.Phoenix.{ConfirmationController, Mailer}

  @impl true
  def before_process(Pow.Phoenix.RegistrationController, :update, conn, _config) do
    user = Plug.current_user(conn)

    Conn.put_private(conn, :pow_user_before_update, user)
  end

  @impl true
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    conn
    |> Plug.current_user()
    |> halt_unconfirmed(conn, {:ok, conn}, :session)
  end
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    halt_unconfirmed(user, conn, {:ok, user, conn}, :registration)
  end
  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, _config), do: warn_unconfirmed(user, conn)
  def before_respond(PowInvitation.Phoenix.InvitationController, :update, {:ok, user, conn}, _config), do: warn_unconfirmed(user, conn)

  defp warn_unconfirmed(%{unconfirmed_email: new_email} = user, %{private: %{pow_user_before_update: %{unconfirmed_email: old_email}}} = conn) when new_email != old_email do
    do_warn_unconfirmed(user, conn)
  end
  defp warn_unconfirmed(user, %{private: %{pow_user_before_update: _user}} = conn), do: {:ok, user, conn}
  defp warn_unconfirmed(%{email_confirmed_at: nil, email_confirmation_token: token} = user, conn) when not is_nil(token) do
    do_warn_unconfirmed(user, conn)
  end
  defp warn_unconfirmed(user, conn), do: {:ok, user, conn}

  defp do_warn_unconfirmed(user, conn) do
    send_confirmation_email(user, conn)

    error = messages(conn).email_confirmation_required_for_update(conn)
    conn  = Phoenix.Controller.put_flash(conn, :error, error)

    {:ok, user, conn}
  end

  defp halt_unconfirmed(%{email_confirmed_at: nil, email_confirmation_token: token} = user, conn, _success_response, type) when not is_nil(token) do
    send_confirmation_email(user, conn)

    {:ok, conn} = Plug.clear_authenticated_user(conn)
    error       = messages(conn).email_confirmation_required(conn)
    path        = return_path(conn, type)
    conn        =
      conn
      |> Phoenix.Controller.put_flash(:error, error)
      |> Phoenix.Controller.redirect(to: path)

    {:halt, conn}
  end
  defp halt_unconfirmed(_user, _conn, success_response, _type), do: success_response

  defp return_path(conn, :registration), do: routes(conn).after_registration_path(conn)
  defp return_path(conn, :session), do: routes(conn).after_sign_in_path(conn)

  @spec send_confirmation_email(map(), Conn.t()) :: any()
  def send_confirmation_email(user, conn) do
    token = user.email_confirmation_token
    url   = routes(conn).url_for(conn, ConfirmationController, :show, [token])
    email = Mailer.email_confirmation(conn, user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end
end
