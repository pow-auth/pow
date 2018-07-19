defmodule Authex.Phoenix.RegistrationController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Authex.Plug
  alias Authex.Phoenix.{Controller, PlugErrorHandler, ViewHelpers}

  plug Plug.RequireNotAuthenticated, [error_handler: PlugErrorHandler] when action in [:new, :create]
  plug Plug.RequireAuthenticated, [error_handler: PlugErrorHandler] when action in [:edit, :update, :delete]

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Plug.change_user(conn)
    render_new(conn, changeset)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    conn
    |> Plug.create_user(user_params)
    |> after_create(conn)
  end

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, _params) do
    changeset = Plug.change_user(conn)
    render_edit(conn, changeset)
  end

  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"user" => user_params}) do
    conn
    |> Plug.update_user(user_params)
    |> after_update(conn)
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> Plug.delete_user()
    |> after_delete(conn)
  end

  defp after_create({:ok, conn}, _conn) do
    conn
    |> put_flash(:info, Controller.messages(conn).message(:user_has_been_created, conn))
    |> redirect(to: Controller.routes(conn).after_registration_path(conn))
  end
  defp after_create({:error, changeset}, conn) do
    render_new(conn, changeset)
  end

  defp after_update({:ok, conn}, _conn) do
    conn
    |> put_flash(:info, Controller.messages(conn).message(:user_has_been_updated,conn))
    |> redirect(to: Controller.routes(conn).after_user_updated_path(conn))
  end
  defp after_update({:error, changeset}, conn) do
    render_edit(conn, changeset)
  end

  defp after_delete({:ok, conn}, _conn) do
    conn
    |> put_flash(:info, Controller.messages(conn).message(:user_has_been_deleted, conn))
    |> redirect(to: Controller.routes(conn).after_user_deleted_path(conn))
  end
  defp after_delete({:error, _changeset}, conn) do
    conn
    |> put_flash(:info, Controller.messages(conn).message(:user_could_not_be_deleted, conn))
    |> redirect(to: Controller.router_helpers(conn).authex_registration_path(conn, :edit))
  end

  defp render_new(conn, changeset) do
    action = Controller.router_helpers(conn).authex_registration_path(conn, :create)
    ViewHelpers.render(conn, "new.html", changeset: changeset, action: action)
  end

  defp render_edit(conn, changeset) do
    action = Controller.router_helpers(conn).authex_registration_path(conn, :update)
    ViewHelpers.render(conn, "edit.html", changeset: changeset, action: action)
  end
end
