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
  user enumeration.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Pow.Plug, as: PowPlug
  alias PowEmailConfirmation.Phoenix.Base
  alias PowEmailConfirmation.Plug

  @doc false
  @impl true
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:ok, user, conn}, _config) do
    conn
    |> Base.send_confirmation_email()
    |> Phoenix.Controller.put_flash(:info, extension_messages(conn).email_confirmation_required(conn))
    |> halt_or_continue({:ok, user, conn})
  end
  def before_respond(Pow.Phoenix.RegistrationController, :create, {:error, changeset, conn}, _config) do
    unconfirmed_access_allowed = !!Pow.Config.get(Pow.Plug.fetch_config(conn), :allow_unconfirmed_access)
    case {unconfirmed_access_allowed, PowPlug.__prevent_user_enumeration__(conn, changeset)} do
      {false, true} ->
        {:halt, conn}
      _ ->
        {:error, changeset, conn}
    end
  end
  def before_respond(Pow.Phoenix.RegistrationController, :update, {:ok, user, conn}, _config) do
    warn_unconfirmed(conn, user)
  end
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    halt_or_continue(conn, {:ok, conn})
  end
  def before_respond(PowInvitation.Phoenix.InvitationController, :update, {:ok, user, conn}, _config) do
    warn_unconfirmed(conn, user)
  end

  defp halt_or_continue(conn, success_response) do
    unconfirmed_access_allowed = !!Pow.Config.get(Pow.Plug.fetch_config(conn), :allow_unconfirmed_access)
    email_is_unconfirmed = Plug.email_unconfirmed?(conn)

    case {unconfirmed_access_allowed, email_is_unconfirmed} do
      {false, true} ->
        conn =
          conn
          |> PowPlug.delete()
          |> Phoenix.Controller.put_flash(:error, extension_messages(conn).email_confirmation_required(conn))
          |> Phoenix.Controller.redirect(to: routes(conn).session_path(conn, :new))
        {:halt, conn}

      _otherwise ->
        success_response
    end
  end

  defp warn_unconfirmed(%{params: %{"user" => %{"email" => email}}} = conn, %{unconfirmed_email: email} = user) do
    case Plug.pending_email_change?(conn) do
      true  ->
        conn = conn
        |> Base.send_confirmation_email()
        |> Phoenix.Controller.put_flash(:info, extension_messages(conn).email_confirmation_required_for_update(conn))

        {:ok, user, conn}
      false ->
        {:ok, user, conn}
    end
  end
  defp warn_unconfirmed(conn, user), do: {:ok, user, conn}
end
