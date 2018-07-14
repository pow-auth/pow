defmodule Authex.Phoenix.SessionController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Authex.Plug
  alias Authex.Phoenix.{Messages, PlugErrorHandler, RouterHelpers, ViewHelpers}

  plug Plug.RequireNotAuthenticated, [error_handler: PlugErrorHandler] when action in [:new, :create]
  plug Plug.RequireAuthenticated, [error_handler: PlugErrorHandler] when action in [:delete]

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Plug.change_user(conn)
    render_new(conn, changeset)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    conn
    |> Plug.authenticate_user(user_params)
    |> handle_authentication(user_params)
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> Plug.clear_authenticated_user()
    |> put_flash(:info, Messages.signed_out())
    |> redirect(to: RouterHelpers.after_sign_out_path(conn))
  end

  defp handle_authentication({:error, conn}, params) do
    changeset = Plug.change_user(conn, params)

    conn
    |> put_flash(:error, Messages.invalid_credentials())
    |> render_new(changeset)
  end
  defp handle_authentication({:ok, conn}, _params) do
    conn
    |> put_flash(:info, Messages.signed_in())
    |> redirect(to: RouterHelpers.after_sign_in_path(conn))
  end

  defp render_new(conn, changeset) do
    action      = RouterHelpers.helpers(conn).authex_registration_path(conn, :create)
    ViewHelpers.render(conn, "new.html", changeset: changeset, action: action)
  end
end
