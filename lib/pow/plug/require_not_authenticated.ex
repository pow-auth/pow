defmodule Pow.Plug.RequireNotAuthenticated do
  @moduledoc """
  This plug ensures that a user hasn't already been authenticated.

  You can see `Pow.Phoenix.PlugErrorHandler` for an example of the error
  handler module.

  ## Example

      plug Pow.Plug.RequireNotAuthenticated,
        error_handler: MyAppWeb.Pow.ErrorHandler
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

  defp maybe_halt(nil, conn, _handler), do: conn
  defp maybe_halt(_user, conn, handler) do
    conn
    |> handler.call(:already_authenticated)
    |> Conn.halt()
  end

  @spec raise_no_error_handler!() :: no_return()
  defp raise_no_error_handler!,
    do: Config.raise_error("No :error_handler configuration option provided. It's required to set this when using #{inspect __MODULE__}.")
end
