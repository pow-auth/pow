defmodule PowEmailConfirmation.Phoenix.ConfirmationController do
  @moduledoc false
  use Pow.Phoenix.Web, :controller

  alias Pow.Extension.Phoenix.Controller, as: ExtensionController
  alias Pow.Phoenix.Controller
  alias PowEmailConfirmation.{Phoenix.Messages, Plug}

  @spec show(Conn.t(), map()) :: Conn.t()
  def show(conn, %{"id" => token}) do
    case Plug.confirm_email(conn, token) do
      {:ok, conn} ->
        conn
        |> put_flash(:info, ExtensionController.message(Messages, :email_has_been_confirmed, conn))
        |> redirect(to: Controller.router_helpers(conn).pow_registration_path(conn, :edit))

      {:error, conn} ->
        conn
        |> put_flash(:error, ExtensionController.message(Messages, :email_confirmation_failed, conn))
        |> redirect(to: Controller.router_helpers(conn).pow_registration_path(conn, :edit))
    end
  end
end
