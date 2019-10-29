defmodule PowResetPassword.Phoenix.ResetPasswordController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias PowResetPassword.{Phoenix.Mailer, Plug}

  plug :require_not_authenticated
  plug :load_user_from_reset_token when action in [:edit, :update]
  plug :assign_create_path when action in [:new, :create]
  plug :assign_update_path when action in [:edit, :update]

  @spec process_new(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_new(conn, _params) do
    {:ok, Plug.change_user(conn), conn}
  end

  @spec respond_new({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_new({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  @spec process_create(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_create(conn, %{"user" => user_params}) do
    Plug.create_reset_token(conn, user_params)
  end

  @spec respond_create({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:ok, %{token: token, user: user}, conn}) do
    url = routes(conn).url_for(conn, __MODULE__, :edit, [token])
    deliver_email(conn, user, url)

    default_respond_create(conn)
  end
  def respond_create({:error, _any, conn}) do
    case registration_path?(conn) do
      true ->
        conn
        |> assign(:changeset, Plug.change_user(conn, conn.params["user"]))
        |> put_flash(:error, extension_messages(conn).user_not_found(conn))
        |> render("new.html")

      false ->
        default_respond_create(conn)
    end
  end

  defp default_respond_create(conn) do
    conn
    |> put_flash(:info, extension_messages(conn).email_has_been_sent(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end

  @spec process_edit(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_edit(conn, _params) do
    {:ok, Plug.change_user(conn), conn}
  end

  @spec respond_edit({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_edit({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  @spec process_update(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_update(conn, %{"user" => user_params}) do
    Plug.update_user_password(conn, user_params)
  end

  @spec respond_update({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_update({:ok, _user, conn}) do
    conn
    |> put_flash(:info, extension_messages(conn).password_has_been_reset(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end
  def respond_update({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  defp load_user_from_reset_token(%{params: %{"id" => token}} = conn, _opts) do
    case Plug.user_from_token(conn, token) do
      nil ->
        conn
        |> put_flash(:error, extension_messages(conn).invalid_token(conn))
        |> redirect(to: routes(conn).path_for(conn, __MODULE__, :new))
        |> halt()

      user ->
        Plug.assign_reset_password_user(conn, user)
    end
  end

  defp deliver_email(conn, user, url) do
    email = Mailer.reset_password(conn, user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end

  defp registration_path?(conn) do
    [conn.private.phoenix_router, Helpers]
    |> Module.concat()
    |> function_exported?(:pow_registration_path, 3)
  end

  defp assign_create_path(conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :create)
    Conn.assign(conn, :action, path)
  end

  defp assign_update_path(conn, _opts) do
    token = conn.params["id"]
    path  = routes(conn).path_for(conn, __MODULE__, :update, [token])
    Conn.assign(conn, :action, path)
  end
end
