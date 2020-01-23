defmodule Pow.Extension.Phoenix.Messages do
  @moduledoc """
  Module that handles messages for extensions.

  To override messages from extensions, the method name has to start with the
  snake cased extension name. So the `a_message/1` method from
  `PowExtensionOne`, should be written as `pow_extension_one_a_message/1`.

  ## Usage

      defmodule MyAppWeb.Pow.Messages do
        use Pow.Phoenix.Messages
        use Pow.Extension.Phoenix.Messages,
          extensions: [PowExtensionOne, PowExtensionTwo]

        import MyAppWeb.Gettext

        def pow_extension_one_a_message(_conn), do: gettext("A message.")

        def pow_extension_two_a_message(_conn), do: gettext("A message.")
      end

  Remember to update configuration with `messages_backend: MyAppWeb.Pow.Messages`.
  """
  alias Pow.Extension

  @doc false
  defmacro __using__(config) do
    quote do
      unquote(config)
      |> unquote(__MODULE__).__messages_modules__()
      |> Enum.map(&unquote(__MODULE__).__define_message_methods__/1)
    end
  end

  @doc false
  def __messages_modules__(config) do
    config
    |> Extension.Config.extensions()
    |> Extension.Config.extension_modules(["Phoenix", "Messages"])
  end

  @doc false
  defmacro __define_message_methods__(extension) do
    quote do
      extension = unquote(extension)
      methods   = extension.__info__(:functions)

      for {fallback_method, 1} <- methods do
        method_name = unquote(__MODULE__).method_name(extension, fallback_method)
        unquote(__MODULE__).__define_message_method__(extension, method_name, fallback_method)
      end

      unquote(__MODULE__).__define_fallback_module__(extension, methods)
    end
  end

  @doc false
  defmacro __define_message_method__(extension, method_name, fallback_method) do
    quote bind_quoted: [extension: extension, method_name: method_name, fallback_method: fallback_method] do
      @spec unquote(method_name)(Conn.t()) :: Messages.message()
      def unquote(method_name)(conn) do
        unquote(extension).unquote(fallback_method)(conn)
      end

      defoverridable [{method_name, 1}]
    end
  end

  @doc false
  defmacro __define_fallback_module__(extension, methods) do
    quote do
      name   = Module.concat([__MODULE__, unquote(extension)])
      quoted = for {method, 1} <- unquote(methods) do
        method_name = unquote(__MODULE__).method_name(unquote(extension), method)

        quote do
          @spec unquote(method)(Conn.t()) :: binary()
          def unquote(method)(conn) do
            unquote(__MODULE__).unquote(method_name)(conn)
          end
        end
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end

  @doc """
  Generates a namespaced method name for a message method.
  """
  @spec method_name(atom(), atom()) :: atom()
  def method_name(extension, type) do
    namespace = namespace(extension)

    String.to_atom("#{namespace}_#{type}")
  end

  defp namespace(extension) do
    ["Messages", "Phoenix" | base] =
      extension
      |> Module.split()
      |> Enum.reverse()

    base
    |> Enum.reverse()
    |> Enum.join()
    |> Macro.underscore()
  end
end
