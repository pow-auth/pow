defmodule Pow.Plug.RequireAuthenticated do
  @moduledoc """
  This plug ensures that a user has been authenticated.

  Example:

    plug Pow.Plug.RequireAuthenticated,
      error_handler: MyApp.CustomErrorHandler

  You can see `Pow.Phoenix.PlugErrorHandler` for an example of the error
  handler module.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @spec init(Config.t()) :: nil
  def init(config), do: config

  @spec call(Conn.t(), Config.t()) :: Conn.t()
  def call(conn, config) do
    conn
    |> Plug.current_user()
    |> maybe_halt(conn, config)
  end

  defp maybe_halt(nil, conn, config) do
    handler = Config.get(config, :error_handler, nil)

    case handler do
      nil ->
        Conn.halt(conn)

      handler ->
        conn
        |> handler.call(:not_authenticated)
        |> Conn.halt()
    end
  end
  defp maybe_halt(_user, conn, _config), do: conn
end
