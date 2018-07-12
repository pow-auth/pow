defmodule Authex.Plug.RequireAuthenticated do
  @moduledoc """
  This plug ensures that a user has been authenticated.

  Example:

    plug Authex.Plug.Session,
      current_user_assigns_key: :current_user
    plug Authex.Plug.RequireAuthenticated,
      error_handler: Authex.Phoenix.ErrorHandler
  """
  alias Plug.Conn
  alias Authex.{Config, Plug, Phoenix.ErrorHandler}

  @spec init(Config.t()) :: nil
  def init(config), do: config

  @spec call(Conn.t(), Config.t()) :: Conn.t()
  def call(conn, config) do
    conn
    |> Plug.current_user()
    |> maybe_halt(conn, config)
  end

  defp maybe_halt(nil, conn, config) do
    handler = Config.get(config, :error_handler, ErrorHandler)

    conn
    |> handler.call(:not_authenticated)
    |> Conn.halt()
  end
  defp maybe_halt(_user, conn, _config), do: conn
end
