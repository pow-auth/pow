defmodule Pow.Phoenix.SessionController do
  @moduledoc false
  use Pow.Phoenix.Controller

  alias Plug.Conn
  alias Pow.Plug

  plug :require_not_authenticated when action in [:new, :create]
  plug :require_authenticated when action in [:delete]
  plug :assign_request_url when action in [:new, :create]
  plug :assign_create_path when action in [:new, :create]

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
    Plug.authenticate_user(conn, user_params)
  end

  @spec respond_create({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:ok, _user, conn}) do
    conn
    |> put_flash(:info, messages(conn).signed_in(conn))
    |> redirect(to: routes(conn).after_sign_in_path(conn))
  end
  def respond_create({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> put_flash(:error, messages(conn).invalid_credentials(conn))
    |> render("new.html")
  end

  @spec process_delete(Conn.t(), map()) :: {:ok, Conn.t()}
  def process_delete(conn, _params), do: Plug.clear_authenticated_user(conn)

  @spec respond_delete({:ok, Conn.t()}) :: Conn.t()
  def respond_delete({:ok, conn}) do
    conn
    |> put_flash(:info, messages(conn).signed_out(conn))
    |> redirect(to: routes(conn).after_sign_out_path(conn))
  end

  defp assign_request_url(%{params: %{"request_url" => request_url}} = conn, _opts) do
    Conn.assign(conn, :request_url, request_url)
  end
  defp assign_request_url(conn, _opts), do: conn

  defp assign_create_path(conn, _opts) do
    Conn.assign(conn, :action, create_path(conn))
  end

  defp create_path(%{assigns: %{request_url: request_url}} = conn) do
    create_path(conn, request_url: request_url)
  end
  defp create_path(conn, params \\ []) do
    router_helpers(conn).pow_session_path(conn, :create, params)
  end
end
