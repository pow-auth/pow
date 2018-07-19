defmodule Authex.Phoenix.Controller do
  @moduledoc """
  Used with Authex Phoenix controllers to handle messages and routes.
  """
  alias Authex.{Config, Phoenix.Messages, Phoenix.Routes, Plug}

  @spec messages(Conn.t()) :: atom()
  def messages(conn) do
    conn
    |> Plug.fetch_config()
    |> Config.get(:messages_backend, Messages)
  end

  @spec routes(Conn.t()) :: atom()
  def routes(conn) do
    conn
    |> Plug.fetch_config()
    |> Config.get(:routes_backend, Routes)
  end

  @spec router_helpers(Conn.t()) :: atom()
  def router_helpers(%{private: private}) do
    Module.concat([private[:phoenix_router], Helpers])
  end
end
