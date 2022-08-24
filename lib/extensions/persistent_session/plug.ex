defmodule PowPersistentSession.Plug do
  @moduledoc """
  Plug helper functions.
  """
  alias Plug.Conn
  alias Pow.Config

  @doc """
  Create a new persistent session in the connection for user.
  """
  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, user) do
    {plug, config} = pow_persistent_session(conn)

    plug.create(conn, user, config)
  end

  @doc """
  Deletes the persistent session in the connection.
  """
  @spec delete(Conn.t()) :: Conn.t()
  def delete(conn) do
    {plug, config} = pow_persistent_session(conn)

    plug.delete(conn, config)
  end

  defp pow_persistent_session(conn) do
    conn.private[:pow_persistent_session] || raise_no_plug_error!()
  end

  @spec raise_no_plug_error!() :: no_return()
  defp raise_no_plug_error!,
    do: Config.raise_error("PowPersistentSession plug module not installed. Please add the PowPersistentSession.Plug.Cookie plug to your endpoint.")
end
