defmodule Authex.Phoenix.RouterHelpers do
  @moduledoc """
  Module that handles routes.
  """
  alias Plug.Conn
  alias Authex.{Authorization.Plug, Config}

  @spec helpers(Conn.t()) :: atom()
  def helpers(%{private: private}) do
    Module.concat([private[:phoenix_router], Helpers])
  end

  @spec after_sign_out_path(Conn.t()) :: binary()
  def after_sign_out_path(conn) do
    config = Plug.fetch_config(conn)
    Config.get(config, :after_sign_out_path, helpers(conn).authex_session_path(conn, :new))
  end

  @spec after_sign_in_path(Conn.t()) :: binary()
  def after_sign_in_path(conn) do
    config = Plug.fetch_config(conn)
    Config.get(config, :after_sign_in_path, "/")
  end
end
