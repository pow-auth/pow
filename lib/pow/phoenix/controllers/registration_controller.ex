defmodule Pow.Phoenix.RegistrationController do
  @moduledoc false
  use Pow.Phoenix.Controller

  alias Plug.Conn
  alias Pow.Plug

  plug :require_not_authenticated when action in [:new, :create]
  plug :require_authenticated when action in [:edit, :update, :delete]
  plug :assign_create_path when action in [:new, :create]
  plug :assign_update_path when action in [:edit, :update]
  plug :put_no_cache_header when action in [:new]

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
    Plug.create_user(conn, user_params)
  end

  @spec respond_create({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_create({:ok, _user, conn}) do
    routes(conn).after_registration(conn)
  end
  def respond_create({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("new.html")
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
    Plug.update_user(conn, user_params)
  end

  @spec respond_update({:ok, map(), Conn.t()}) :: Conn.t()
  def respond_update({:ok, _user, conn}) do
    routes(conn).after_user_updated(conn)
  end
  def respond_update({:error, changeset, conn}) do
    conn
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  @spec process_delete(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_delete(conn, _params) do
    Plug.delete_user(conn)
  end

  @spec respond_delete({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_delete({:ok, _user, conn}) do
    routes(conn).after_user_deleted(conn)
  end
  def respond_delete({:error, _changeset, conn}) do
    routes(conn).after_user_not_deleted(conn)
  end

  defp assign_create_path(conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :create)
    Conn.assign(conn, :action, path)
  end

  defp assign_update_path(conn, _opts) do
    path = routes(conn).path_for(conn, __MODULE__, :update)
    Conn.assign(conn, :action, path)
  end
end
