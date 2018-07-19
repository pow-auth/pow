defmodule Authex.Phoenix.RegistrationController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Plug.Conn
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
    config = Plug.fetch_config(conn)
    res    = Plug.create_user(conn, user_params)

    res
    |> Controller.callback(__MODULE__, :create, config)
    |> after_create()
  end

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, _params) do
    changeset = Plug.change_user(conn)
    render_edit(conn, changeset)
  end

  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"user" => user_params}) do
    config = Plug.fetch_config(conn)
    res    = Plug.update_user(conn, user_params)

    res
    |> Controller.callback(__MODULE__, :update, config)
    |> after_update()
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    config = Plug.fetch_config(conn)
    res    = Plug.delete_user(conn)

    res
    |> Controller.callback(__MODULE__, :delete, config)
    |> after_delete()
  end

  defp after_create({:ok, _user, conn}) do
    conn
    |> put_flash(:info, Controller.messages(conn).user_has_been_created(conn))
    |> redirect(to: Controller.routes(conn).after_registration_path(conn))
  end
  defp after_create({:error, changeset, conn}) do
    render_new(conn, changeset)
  end

  defp after_update({:ok, _user, conn}) do
    conn
    |> put_flash(:info, Controller.messages(conn).user_has_been_updated(conn))
    |> redirect(to: Controller.routes(conn).after_user_updated_path(conn))
  end
  defp after_update({:error, changeset, conn}) do
    render_edit(conn, changeset)
  end

  defp after_delete({:ok, _user, conn}) do
    conn
    |> put_flash(:info, Controller.messages(conn).user_has_been_deleted(conn))
    |> redirect(to: Controller.routes(conn).after_user_deleted_path(conn))
  end
  defp after_delete({:error, _changeset, conn}) do
    conn
    |> put_flash(:info, Controller.messages(conn).user_could_not_be_deleted(conn))
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
