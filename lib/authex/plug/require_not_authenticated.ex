defmodule Authex.Plug.RequireNotAuthenticated do
  @moduledoc """
  This plug ensures that a user hasn't already been authenticated.

  Example:

    plug Authex.Plug.Session,
      current_user_assigns_key: :current_user
    plug Authex.Plug.RequireAuthenticated,
      error_handler: Authex.Phoenix.ErrorHandler
  """
  alias Plug.Conn
  alias Authex.{Config, Plug, Phoenix.ErrorHandler}

  @spec init(Config.t()) :: Config.t()
  def init(config), do: config

  @spec call(Conn.t(), Config.t()) :: Conn.t()
  def call(conn, config) do
    conn
    |> Plug.current_user()
    |> maybe_halt(conn, config)
  end

  defp maybe_halt(nil, conn, _config), do: conn
  defp maybe_halt(_user, conn, config) do
    handler = Config.get(config, :error_handler, ErrorHandler)

    conn
    |> handler.call(:already_authenticated)
    |> Conn.halt()
  end
end
