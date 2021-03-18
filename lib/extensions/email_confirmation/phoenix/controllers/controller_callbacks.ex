defmodule PowEmailConfirmation.Phoenix.ControllerCallbacks do
  @moduledoc """
  Controller callback logic for e-mail confirmation.

  ### User hasn't confirmed e-mail

  Triggers on `Pow.Phoenix.RegistrationController.create/2` and
  `Pow.Phoenix.SessionController.create/2`.

  When a user is created or authenticated, and the current e-mail hasn't been
  confirmed, a confirmation e-mail is sent, the session will be cleared, an
  error flash is set for the `conn` and the user redirected back to
  `Pow.Phoenix.Routes.after_registration_path/1` or
  `Pow.Phoenix.Routes.after_sign_in_path/1` respectively.

  ### User updates e-mail

  Triggers on `Pow.Phoenix.RegistrationController.update/2` and
  `PowInvitation.Phoenix.InvitationController.update/2`

  When a user changes their e-mail, a confirmation e-mail is send to the new
  e-mail, and an error flash is set for the `conn`. The same happens if the
  `PowInvitation` extension is enabled, and a user updates their e-mail when
  accepting their invitation. It's assumed that the current e-mail for the
  invited user has already been confirmed, see
  `PowInvitation.Ecto.Schema.invite_changeset/3` for more.

  See `PowEmailConfirmation.Ecto.Schema` for more.

  ### Unique constraint error on `:email`

  Triggers on `Pow.Phoenix.RegistrationController.create/2`.

  When a user can't be created and the changeset has a unique constraint error
  for the `:email` field, the user will experience the same success flow as if
  the user could be created, but no e-mail is sent out. This prevents
  user enumeration. If `pow_prevent_user_enumeration: false` is set in
  `conn.private` the form with error will be shown instead.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.Plug, as: PowPlug
  alias PowEmailConfirmation.Phoenix.{ConfirmationController, Mailer}
  alias PowEmailConfirmation.Plug

  @doc false
  @impl true
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    return_path = routes(conn).after_registration_path(conn)

    halt_unconfirmed(conn, {:ok, user, conn}, return_path)
  end
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:error, changeset, conn}, _config) do
    case PowPlug.__prevent_user_enumeration__(conn, changeset) do
      true ->
        return_path = routes(conn).after_registration_path(conn)
        conn        = redirect_with_email_confirmation_required(conn, return_path)

        {:halt, conn}

      false ->
        {:error, changeset, conn}
    end
  end
  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, _config) do
    return_path = routes(conn).after_user_updated_path(conn)

    warn_unconfirmed(conn, user, return_path)
  end
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    return_path = routes(conn).after_sign_in_path(conn)

    halt_unconfirmed(conn, {:ok, conn}, return_path)
  end
  def before_respond(PowInvitation.Phoenix.InvitationController, :update, {:ok, user, conn}, _config) do
    return_path = routes(conn).after_registration_path(conn)

    warn_unconfirmed(conn, user, return_path)
  end

  defp halt_unconfirmed(conn, success_response, return_path) do
    case Plug.email_unconfirmed?(conn) do
      true  -> halt_and_send_confirmation_email(conn, return_path)
      false -> success_response
    end
  end

  defp halt_and_send_confirmation_email(conn, return_path) do
    send_confirmation_email(PowPlug.current_user(conn), conn)

    conn =
      conn
      |> PowPlug.delete()
      |> redirect_with_email_confirmation_required(return_path)

    {:halt, conn}
  end

  defp redirect_with_email_confirmation_required(conn, return_path) do
    error = extension_messages(conn).email_confirmation_required(conn)

    conn
    |> Phoenix.Controller.put_flash(:info, error)
    |> Phoenix.Controller.redirect(to: return_path)
  end

  defp warn_unconfirmed(%{params: %{"user" => %{"email" => email}}} = conn, %{unconfirmed_email: email} = user, return_path) do
    case Plug.pending_email_change?(conn) do
      true  -> warn_and_send_confirmation_email(conn, return_path)
      false -> {:ok, user, conn}
    end
  end
  defp warn_unconfirmed(conn, user, _return_path), do: {:ok, user, conn}

  defp warn_and_send_confirmation_email(conn, return_path) do
    user  = PowPlug.current_user(conn)
    error = extension_messages(conn).email_confirmation_required_for_update(conn)

    send_confirmation_email(user, conn)

    conn =
      conn
      |> Phoenix.Controller.put_flash(:info, error)
      |> Phoenix.Controller.redirect(to: return_path)

    {:halt, conn}
  end

  @doc """
  Sends a confirmation e-mail to the user.

  The user struct passed to the mailer will have the `:email` set to the
  `:unconfirmed_email` value if `:unconfirmed_email` is set.
  """
  @spec send_confirmation_email(map(), Conn.t()) :: any()
  def send_confirmation_email(user, conn) do
    url               = confirmation_url(conn, user)
    unconfirmed_user  = %{user | email: user.unconfirmed_email || user.email}
    email             = Mailer.email_confirmation(conn, unconfirmed_user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end

  defp confirmation_url(conn, user) do
    token = Plug.sign_confirmation_token(conn, user)

    routes(conn).url_for(conn, ConfirmationController, :show, [token])
  end
end
