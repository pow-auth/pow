defmodule Pow.Plug.RequireAuthenticated do
  @moduledoc """
  This plug ensures that a user has been authenticated.

  You can see `Pow.Phoenix.PlugErrorHandler` for an example of the error
  handler module.

  ## Example

      plug Pow.Plug.RequireAuthenticated,
        error_handler: MyApp.CustomErrorHandler
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}

  @doc false
  @spec init(Config.t()) :: atom()
  def init(config) do
    Config.get(config, :error_handler) || raise_no_error_handler!()
  end

  @doc false
  @spec call(Conn.t(), atom()) :: Conn.t()
  def call(conn, handler) do
    conn
    |> Plug.current_user()
    |> maybe_halt(conn, handler)
  end

  defp maybe_halt(nil, conn, handler) do
    conn
    |> handler.call(:not_authenticated)
    |> Conn.halt()
  end
  defp maybe_halt(_user, conn, _handler), do: conn

  @spec raise_no_error_handler!() :: no_return()
  defp raise_no_error_handler!,
    do: Config.raise_error("No :error_handler configuration option provided. It's required to set this when using #{inspect __MODULE__}.")
end
