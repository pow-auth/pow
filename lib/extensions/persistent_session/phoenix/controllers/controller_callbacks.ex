defmodule PowPersistentSession.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias PowPersistentSession.Plug

  @impl true
  def before_process(Pow.Phoenix.SessionController, :create, %{params: %{"user" => %{"persistent_session" => "false"}}} = conn, _config) do
    Conn.put_private(conn, :pow_persistent_session_store, false)
  end
  def before_process(Pow.Phoenix.SessionController, :create, conn, _config) do
    Conn.put_private(conn, :pow_persistent_session_store, true)
  end

  @impl true
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, %{private: %{pow_persistent_session_store: true}} = conn}, _config) do
    user = Pow.Plug.current_user(conn)

    {:ok, Plug.create(conn, user)}
  end

  @impl true
  def before_respond(Pow.Phoenix.SessionController, :delete, {:ok, conn}, _config) do
    {:ok, Plug.delete(conn)}
  end
end
