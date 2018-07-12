defmodule Authex.Phoenix.RouterHelpers do
  @moduledoc """
  Module that handles routes.
  """
  alias Plug.Conn
  alias Authex.{Plug, Config}

  @spec helpers(Conn.t()) :: atom()
  def helpers(%{private: private}) do
    Module.concat([private[:phoenix_router], Helpers])
  end

  @spec after_sign_out_path(Conn.t()) :: binary()
  def after_sign_out_path(conn) do
    route(conn, :after_sign_out_path, helpers(conn).authex_session_path(conn, :new))
  end

  @spec after_sign_in_path(Conn.t()) :: binary()
  def after_sign_in_path(conn) do
    route(conn, :after_sign_in_path, "/")
  end

  @spec after_registration_path(Conn.t()) :: binary()
  def after_registration_path(conn) do
    route(conn, :after_registration_path, after_sign_in_path(conn))
  end

  @spec after_user_updated_path(Conn.t()) :: binary()
  def after_user_updated_path(conn) do
    route(conn, :after_user_updated_path, helpers(conn).authex_registration_path(conn, :show))
  end

  @spec after_user_deleted_path(Conn.t()) :: binary()
  def after_user_deleted_path(conn) do
    route(conn, :after_user_deleted_path, after_sign_out_path(conn))
  end

  defp route(conn, path, default) do
    conn
    |> Plug.fetch_config()
    |> Config.get(path, default)
  end
end
