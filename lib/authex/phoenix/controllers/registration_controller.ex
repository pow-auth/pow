defmodule Authex.Phoenix.RegistrationController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Authex.Plug
  alias Authex.Phoenix.{Messages, PlugErrorHandler, RouterHelpers, ViewHelpers}

  plug Plug.RequireNotAuthenticated, [error_handler: PlugErrorHandler] when action in [:new, :create]
  plug Plug.RequireAuthenticated, [error_handler: PlugErrorHandler] when action in [:show, :edit, :update, :delete]

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Plug.change_user(conn)
    render_new(conn, changeset)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    conn
    |> Plug.create_user(user_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Messages.user_has_been_created())
        |> redirect(to: RouterHelpers.after_registration_path(conn))

      {:error, changeset} ->
        render_new(conn, changeset)
    end
  end

  @spec show(Conn.t(), map()) :: Conn.t()
  def show(conn, _params) do
    user = Plug.current_user(conn)
    ViewHelpers.render(conn, "show.html", user: user)
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
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Messages.user_has_been_updated())
        |> redirect(to: RouterHelpers.after_user_updated_path(conn))

      {:error, changeset} ->
        render_edit(conn, changeset)
    end
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> Plug.delete_user()
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Messages.user_has_been_deleted())
        |> redirect(to: RouterHelpers.after_user_deleted_path(conn))

      {:error, _changeset} ->
        conn
        |> put_flash(:info, Messages.user_could_not_be_deleted())
        |> redirect(to: RouterHelpers.helpers(conn).authex_registration_path(conn, :edit))
    end
  end

  defp render_new(conn, changeset) do
    action = RouterHelpers.helpers(conn).authex_registration_path(conn, :create)
    ViewHelpers.render(conn, "new.html", changeset: changeset, action: action)
  end

  defp render_edit(conn, changeset) do
    action = RouterHelpers.helpers(conn).authex_registration_path(conn, :update)
    ViewHelpers.render(conn, "edit.html", changeset: changeset, action: action)
  end
end
