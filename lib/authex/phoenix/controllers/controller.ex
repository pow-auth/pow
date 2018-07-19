defmodule Authex.Phoenix.Controller do
  @moduledoc """
  Used with Authex Phoenix controllers to handle messages, routes and callbacks.

  The following configuration settings are handled here:

  - `:messages_backend`
    See `Authex.Phoenix.Messages` for more.

  - `:routes_backend`
    See `Authex.Phoenix.Routes` for more.

  - `:controller_callbacks`
    See `Authex.Extension.Phoenix.ControllerCallbacks` for more.
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

  @spec callback(any(), atom(), atom(), Keyword.t()) :: any()
  def callback(result, controller, action, config) do
    config
    |> Config.get(:controller_callbacks, nil)
    |> callback_handler(controller, action, result, config)
  end

  defp callback_handler(nil, _controller, _action, result, _config), do: result
  defp callback_handler(module, controller, action, result, config) do
    module.callback(controller, action, result, config)
  end

  @spec router_helpers(Conn.t()) :: atom()
  def router_helpers(%{private: private}) do
    Module.concat([private[:phoenix_router], Helpers])
  end
end
