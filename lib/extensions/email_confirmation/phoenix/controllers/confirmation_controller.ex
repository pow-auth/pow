defmodule AuthexEmailConfirmation.Phoenix.ConfirmationController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Authex.Extension.Phoenix.Controller, as: ExtensionController
  alias Authex.Phoenix.Controller
  alias AuthexEmailConfirmation.{Phoenix.Messages, Plug}

  @spec show(Conn.t(), map()) :: Conn.t()
  def show(conn, %{"id" => token}) do
    case Plug.confirm_email(conn, token) do
      {:ok, conn} ->
        conn
        |> put_flash(:info, ExtensionController.message(Messages, :email_has_been_confirmed, conn))
        |> redirect(to: Controller.router_helpers(conn).authex_registration_path(conn, :edit))

      {:error, conn} ->
        conn
        |> put_flash(:error, ExtensionController.message(Messages, :email_confirmation_failed, conn))
        |> redirect(to: Controller.router_helpers(conn).authex_registration_path(conn, :edit))
    end
  end
end
