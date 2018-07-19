defmodule Authex.Extension.Phoenix.Messages.Base do
  @moduledoc """
  Used for the Phoenix Messages module in extensions.

  ## Usage

      defmodule MyAuthexExtension.Phoenix.Messages do
        use Authex.Extension.Phoenix.Messages.Base

        def message(:custom_messages, _conn), do: "Custom message"
      end
  """
  alias Plug.Conn
  alias Authex.{Config, Extension.Phoenix.Messages, Plug}

  @callback message(atom(), Conn.t) :: binary()

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @spec msg(atom(), Conn.t()) :: binary()
      def msg(type, conn) do
        {mod, method} = mod_method(conn)

        apply(mod, method, [type, conn])
      end

      defp mod_method(conn) do
        conn
        |> Plug.fetch_config()
        |> Config.get(:messages_backend, __MODULE__)
        |> case do
          __MODULE__ -> {__MODULE__, :message}
          mod        -> {mod, Messages.method_name(mod)}
        end
      end
    end
  end
end
