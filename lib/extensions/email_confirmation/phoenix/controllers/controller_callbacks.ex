defmodule PowEmailConfirmation.Phoenix.ControllerCallbacks do
  @moduledoc """
  Controller callback logic for e-mail confirmation.

  ### User hasn't confirmed e-mail

  Triggers on `Pow.Phoenix.RegistrationController.create/2` or
  `Pow.Phoenix.SessionController.create/2`.

  When a user is created or authenticated, and the current e-mail hasn't been
  confirmed, a confirmation e-mail is sent, the session will be cleared, and the
  user redirected back to `Pow.Phoenix.Routes.after_registration_path/1` or
  `Pow.Phoenix.Routes.after_registration_path/1` respectively.

  ### User updates e-mail

  Triggers on `Pow.Phoenix.RegistrationController.update/2` and
  `PowInvitation.Phoenix.InvitationController.update/2`

  When a user changes their e-mail, a confirmation e-mail is send to the new
  e-mail, and an error flash is set for the conn. The same happens if the
  `PowInvitation` extension is enabled, and a user updates their e-mail when
  accepting their invitation. It's assumed that the current e-mail for the
  invited user has already been confirmed, see
  `PowInvitation.Ecto.Schema.invite_changeset/3` for more.

  See `PowEmailConfirmation.Ecto.Schema` for more.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.Plug
  alias PowEmailConfirmation.Phoenix.{ConfirmationController, Mailer}
  alias PowEmailConfirmation.Plug, as: PowEmailConfirmationPlug

  @doc false
  @impl true
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    return_path = routes(conn).after_registration_path(conn)

    halt_unconfirmed(conn, {:ok, user, conn}, return_path)
  end
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    return_path = routes(conn).after_sign_in_path(conn)

    halt_unconfirmed(conn, {:ok, conn}, return_path)
  end
  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, _config),
    do: warn_unconfirmed(conn, user)
  def before_respond(PowInvitation.Phoenix.InvitationController, :update, {:ok, user, conn}, _config),
    do: warn_unconfirmed(conn, user)

  defp halt_unconfirmed(conn, success_response, return_path) do
    case PowEmailConfirmationPlug.email_unconfirmed?(conn) do
      true  -> halt_and_send_confirmation_email(conn, return_path)
      false -> success_response
    end
  end

  defp halt_and_send_confirmation_email(conn, return_path) do
    user        = Plug.current_user(conn)
    {:ok, conn} = Plug.clear_authenticated_user(conn)
    error       = extension_messages(conn).email_confirmation_required(conn)

    send_confirmation_email(user, conn)

    conn =
      conn
      |> Phoenix.Controller.put_flash(:error, error)
      |> Phoenix.Controller.redirect(to: return_path)

    {:halt, conn}
  end

  defp warn_unconfirmed(%{params: %{"user" => %{"email" => email}}} = conn, %{unconfirmed_email: email} = user) do
    case PowEmailConfirmationPlug.pending_email_change?(conn) do
      true  -> warn_and_send_confirmation_email(conn)
      false -> {:ok, user, conn}
    end
  end
  defp warn_unconfirmed(conn, user), do: {:ok, user, conn}

  defp warn_and_send_confirmation_email(conn) do
    user  = Plug.current_user(conn)
    error = extension_messages(conn).email_confirmation_required_for_update(conn)
    conn  = Phoenix.Controller.put_flash(conn, :error, error)

    send_confirmation_email(user, conn)

    {:ok, user, conn}
  end

  @doc """
  Sends a confirmation e-mail to the user.

  The user struct passed to the mailer will have the `:email` set to the
  `:unconfirmed_email` value if `:unconfirmed_email` is set.
  """
  @spec send_confirmation_email(map(), Conn.t()) :: any()
  def send_confirmation_email(user, conn) do
    url               = confirmation_url(conn, user.email_confirmation_token)
    unconfirmed_user  = %{user | email: user.unconfirmed_email || user.email}
    email             = Mailer.email_confirmation(conn, unconfirmed_user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end

  defp confirmation_url(conn, token) do
    routes(conn).url_for(conn, ConfirmationController, :show, [token])
  end
end
