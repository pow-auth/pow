defmodule PowResetPassword.Phoenix.ResetPasswordController do
  @moduledoc false
  use Pow.Phoenix.Web, :controller

  alias Pow.Extension.Phoenix.Controller, as: ExtensionController
  alias Pow.Phoenix.{Controller, PlugErrorHandler, ViewHelpers}
  alias PowResetPassword.Phoenix.{Mailer.ResetPasswordMailer, Messages}
  alias PowResetPassword.Plug

  plug Pow.Plug.RequireNotAuthenticated, [error_handler: PlugErrorHandler]

  plug :load_user_from_reset_token when action in [:edit, :update]

  @spec new(Conn.t(), map()) :: Conn.t()
  def new(conn, _params) do
    changeset = Plug.change_user(conn)
    action = Controller.router_helpers(conn).pow_registration_path(conn, :create)

    ViewHelpers.render(conn, "new.html", changeset: changeset, action: action)
  end

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    user = Plug.load_user(conn, user_params)

    conn
    |> Plug.create_reset_token(user)
    |> case do
      {:error, _any} -> nil
      {:ok, conn} ->
        token = Plug.reset_password_token(conn)
        url = Controller.router_helpers(conn).pow_reset_password_reset_password_path(conn, :edit, token)

        deliver_email(conn, user, url)
    end

    conn
    |> put_flash(:info, ExtensionController.message(Messages, :email_has_been_sent, conn))
    |> redirect(to: Controller.router_helpers(conn).pow_session_path(conn, :new))
  end

  @spec edit(Conn.t(), map()) :: Conn.t()
  def edit(conn, _params) do
    changeset = Plug.change_user(conn)
    render_edit(conn, changeset)
  end

  @spec update(Conn.t(), map()) :: Conn.t()
  def update(conn, %{"user" => user_params}) do
    conn
    |> Plug.update_user_password(user_params)
    |> case do
      {:ok, conn} ->
        conn
        |> put_flash(:info, ExtensionController.message(Messages, :password_has_been_reset, conn))
        |> redirect(to: Controller.router_helpers(conn).pow_session_path(conn, :new))

      {:error, changeset} ->
        render_edit(conn, changeset)
    end
  end

  defp render_edit(conn, changeset) do
    action = Controller.router_helpers(conn).pow_registration_path(conn, :update)
    ViewHelpers.render(conn, "edit.html", changeset: changeset, action: action)
  end

  defp load_user_from_reset_token(%{params: %{"id" => token}} = conn, _opts) do
    case Plug.user_from_token(conn, token) do
      nil ->
        conn
        |> put_flash(:error, ExtensionController.message(Messages, :invalid_token, conn))
        |> redirect(to: Controller.router_helpers(conn).pow_reset_password_reset_password_path(conn, :new))
        |> halt()

      user ->
        Plug.assign_reset_password_user(conn, user)
    end
  end

  defp deliver_email(conn, user, url) do
    email = ResetPasswordMailer.reset_password(user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end
end
