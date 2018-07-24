defmodule Pow.Extension.Phoenix.Controller.Base do
  @moduledoc """
  Used with Pow Extension Phoenix controllers to handle messages and routes.
  """
  alias Pow.{Config, Phoenix.Controller}

  defmacro __using__(config) do
    quote do
      use Controller, unquote(config)

      @messages_fallback Config.get(unquote(config), :messages_backend_fallback, nil)

      def messages(conn) do
        case Controller.messages(conn, @messages_fallback) do
          @messages_fallback -> @messages_fallback
          messages -> Module.concat([messages, @messages_fallback])
        end
      end
    end
  end
end
