defmodule Authex.Extension.Phoenix.Messages do
  @moduledoc """
  Module that handles messages for extensions.

  ## Usage

      defmodule MyAppWeb.Authex.Messages do
        use Authex.Phoenix.Messages
        use Authex.Extension.Phoenix.Messages,
          extensions: [AuthexExtensionOne, AuthexExtensionTwo]

        def authex_extension_one(:a_message, _conn), do: "A message."
      end
  """
  alias Authex.{Config, Extension}

  defmacro __using__(config) do
    quote do
      extensions = unquote(__MODULE__).__messages_extensions___(unquote(config))
      Module.put_attribute(__MODULE__, :message_extensions, extensions)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      for extension <- @message_extensions do
        method_name = unquote(__MODULE__).method_name(extension)
        unquote(__MODULE__).__message_methods_for_extension__(extension, method_name)
      end
    end
  end

  @spec __messages_extensions___(Config.t()) :: [atom()]
  def __messages_extensions___(config) do
    config
    |> Extension.Config.extensions()
    |> Enum.map(&Module.concat([&1, "Phoenix", "Messages"]))
    |> Enum.filter(&Code.ensure_compiled?/1)
    |> Enum.reject(&is_nil/1)
  end

  defmacro __message_methods_for_extension__(extension, method_name) do
    quote bind_quoted: [method_name: method_name, extension: extension] do
      @spec unquote(method_name)(atom(), Conn.t()) :: binary()
      def unquote(method_name)(type, conn) do
        unquote(extension).message(type, conn)
      end
    end
  end

  @spec method_name(atom()) :: atom()
  def method_name(extension) do
    extension
    |> Module.split()
    |> List.first()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
