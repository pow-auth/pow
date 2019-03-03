defmodule Pow.Extension.Phoenix.Controller.Base do
  @moduledoc """
  Used with Pow Extension Phoenix controllers to handle messages and routes.

  ## Usage

      defmodule MyPowExtension.Phoenix.CustomController do
        use Pow.Extension.Phoenix.Controller.Base,
          messages_backend_fallback: MyPowExtension.Phoenix.Messages

        # ...
      end
  """
  alias Pow.{Config, Phoenix.Controller}

  @doc false
  defmacro __using__(config) do
    quote do
      use Controller, unquote(config)

      @messages_fallback Config.get(unquote(config), :messages_backend_fallback)

      def messages(conn) do
        case Controller.messages(conn, @messages_fallback) do
          @messages_fallback -> @messages_fallback
          messages -> Module.concat([messages, @messages_fallback])
        end
      end
    end
  end
end
