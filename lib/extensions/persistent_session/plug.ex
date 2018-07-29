defmodule PowPersistentSession.Plug do
  @moduledoc false
  alias Plug.Conn
  alias Pow.Config

  @spec create(Conn.t(), map()) :: Conn.t() | no_return
  def create(conn, user) do
    {mod, config} = pow_persistent_session(conn)

    mod.create(conn, user, config)
  end

  @spec delete(Conn.t()) :: Conn.t() | no_return
  def delete(conn) do
    {mod, config} = pow_persistent_session(conn)

    mod.delete(conn, config)
  end

  defp pow_persistent_session(conn) do
    conn.private[:pow_persistent_session] || raise_no_mod_error()
  end

  @spec raise_no_mod_error :: no_return
  defp raise_no_mod_error do
    Config.raise_error("PowPersistentSession plug module not installed. Please add the PowPersistentSession.Plug.Cookie plug to your endpoint.")
  end
end
