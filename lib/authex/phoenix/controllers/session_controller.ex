defmodule Authex.Phoenix.SessionController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Authex.Plug
  alias Authex.Phoenix.{Controller, PlugErrorHandler, ViewHelpers}

  plug Plug.RequireNotAuthenticated, [error_handler: PlugErrorHandler] when action in [:new, :create]
  plug Plug.RequireAuthenticated, [error_handler: PlugErrorHandler] when action in [:delete]

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Plug.change_user(conn)
    render_new(conn, changeset)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    config = Plug.fetch_config(conn)
    res    = Plug.authenticate_user(conn, user_params)

    res
    |> Controller.callback(__MODULE__, :create, config)
    |> after_create(user_params)
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    config = Plug.fetch_config(conn)
    res    = Plug.clear_authenticated_user(conn)

    res
    |> Controller.callback(__MODULE__, :delete, config)
    |> after_delete()
  end

  defp after_create({:ok, conn}, _params) do
    conn
    |> put_flash(:info, Controller.messages(conn).signed_in(conn))
    |> redirect(to: Controller.routes(conn).after_sign_in_path(conn))
  end
  defp after_create({:error, conn}, params) do
    changeset = Plug.change_user(conn, params)

    conn
    |> put_flash(:error, Controller.messages(conn).invalid_credentials(conn))
    |> render_new(changeset)
  end

  defp after_delete(conn) do
    conn
    |> put_flash(:info, Controller.messages(conn).signed_out(conn))
    |> redirect(to: Controller.routes(conn).after_sign_out_path(conn))
  end

  defp render_new(conn, changeset) do
    action = Controller.router_helpers(conn).authex_registration_path(conn, :create)
    ViewHelpers.render(conn, "new.html", changeset: changeset, action: action)
  end
end
