defmodule PowPersistentSession.Phoenix.ControllerCallbacks do
  @moduledoc false
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias PowPersistentSession.Plug

  @impl true
  def before_process(Pow.Phoenix.SessionController, :create, conn, _config) do
    store = Map.get(conn.params["user"], "persistent_session", "true")

    Conn.put_private(conn, :store_persistent_session?, store)
  end

  @impl true
  def before_respond(Pow.Phoenix.SessionController, :create, {:ok, conn}, _config) do
    user = Pow.Plug.current_user(conn)

    case conn.private[:store_persistent_session?] do
      "true" -> {:ok, Plug.create(conn, user)}
      _any   -> {:ok, conn}
    end
  end

  @impl true
  def before_respond(Pow.Phoenix.SessionController, :delete, {:ok, conn}, _config) do
    {:ok, Plug.delete(conn)}
  end
end
