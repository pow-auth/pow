defmodule Authex.Phoenix.RegistrationController do
  @moduledoc false
  use Authex.Phoenix.Web, :controller

  alias Authex.{Operations,
                Authorization.Plug,
                Authorization.Plug.RequireAuthenticated,
                Authorization.Plug.RequireNotAuthenticated,
                Phoenix.RouterHelpers,
                Phoenix.ViewHelpers,
                Phoenix.Messages}

  plug RequireNotAuthenticated when action in [:new, :create]
  plug RequireAuthenticated when action in [:show, :edit, :update, :delete]

  def new(conn, _params) do
    changeset = Plug.changeset_user(conn)

    ViewHelpers.render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    conn
    |> Plug.create_user(user_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Messages.user_has_been_created())
        |> redirect(to: RouterHelpers.after_registration_path(conn))

      {:error, changeset} ->
        ViewHelpers.render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, _params) do
    user = Plug.current_user(conn)

    ViewHelpers.render(conn, "show.html", user: user)
  end

  def edit(conn, _params) do
    user      = Plug.current_user(conn)
    changeset =
      conn
      |> Plug.fetch_config()
      |> Operations.changeset(user)

      ViewHelpers.render(conn, "edit.html", changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    conn
    |> Plug.update_user(user_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Messages.user_has_been_updated())
        |> redirect(to: RouterHelpers.after_user_updated_path(conn))

      {:error, changeset} ->
        ViewHelpers.render(conn, "edit.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    conn
    |> Plug.delete_user()
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, Messages.user_has_been_deleted())
        |> redirect(to: RouterHelpers.after_user_deleted_path(conn))

      {:error, changeset} ->
        ViewHelpers.render(conn, "edit.html", changeset: changeset)
    end
  end
end
