defmodule Pow.Phoenix.SessionController do
  @moduledoc """
  Controller actions for session.

  The `:request_path` param will automatically be assigned in `:new` and
  `:create` actions, and used for the `pow_session_path(conn, :create)` path.
  """
  use Pow.Phoenix.Controller

  alias Plug.Conn
  alias Pow.Plug

  plug :require_not_authenticated when action in [:new, :create]
  plug :require_authenticated when action in [:delete]
  plug :assign_request_path when action in [:new, :create]
  plug :assign_create_path when action in [:new, :create]
  plug :put_no_cache_header when action in [:new]

  @doc false
  @spec process_new(Conn.t(), map()) :: {:ok, map(), Conn.t()}
  def process_new(conn, _params) do
    {:ok, Plug.change_user(conn), conn}
  end

  @doc false
  @spec respond_new({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_new({:ok, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
  end

  @doc false
  @spec process_create(Conn.t(), map()) :: {:ok | :error, Conn.t()}
  def process_create(conn, %{"user" => user_params}) do
    Plug.authenticate_user(conn, user_params)
  end

  @doc false
  @spec respond_create({:ok | :error, Conn.t()}) :: Conn.t()
  def respond_create({:ok, conn}) do
    conn
    |> put_flash(:info, messages(conn).signed_in(conn))
    |> redirect(to: routes(conn).after_sign_in_path(conn))
  end
  def respond_create({:error, conn}) do
    conn
    |> assign(:changeset, Plug.change_user(conn, conn.params["user"]))
    |> put_flash(:error, messages(conn).invalid_credentials(conn))
    |> render("new.html")
  end

  @doc false
  @spec process_delete(Conn.t(), map()) :: {:ok, Conn.t()}
  def process_delete(conn, _params), do: {:ok, Plug.delete(conn)}

  @doc false
  @spec respond_delete({:ok, Conn.t()}) :: Conn.t()
  def respond_delete({:ok, conn}) do
    conn
    |> put_flash(:info, messages(conn).signed_out(conn))
    |> redirect(to: routes(conn).after_sign_out_path(conn))
  end

  defp assign_request_path(%{params: %{"request_path" => request_path}} = conn, _opts) do
    Conn.assign(conn, :request_path, request_path)
  end
  defp assign_request_path(conn, _opts), do: conn

  defp assign_create_path(conn, _opts) do
    Conn.assign(conn, :action, create_path(conn))
  end

  defp create_path(%{assigns: %{request_path: request_path}} = conn) do
    create_path(conn, request_path: request_path)
  end
  defp create_path(conn, query_params \\ []) do
    routes(conn).path_for(conn, __MODULE__, :create, [], query_params)
  end
end
