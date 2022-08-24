defmodule Pow.Extension.Phoenix.Messages do
  @moduledoc """
  Module that handles messages for extensions.

  To override messages from extensions, the function name has to start with the
  snake cased extension name. So the `a_message/1` function from
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

  defmodule Helpers do
    @moduledoc false

    def function_name(extension, type) do
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

  @doc false
  defmacro __using__(config) do
    quote do
      unquote(config)
      |> unquote(__MODULE__).__messages_modules__()
      |> Enum.map(&unquote(__MODULE__).__define_message_functions__/1)
    end
  end

  @doc false
  def __messages_modules__(config) do
    config
    |> Extension.Config.extensions()
    |> Extension.Config.extension_modules(["Phoenix", "Messages"])
  end

  @doc false
  defmacro __define_message_functions__(extension) do
    quote do
      extension = unquote(extension)
      functions = extension.__info__(:functions)

      for {fallback_function, 1} <- functions do
        function_name = unquote(__MODULE__).Helpers.function_name(extension, fallback_function)
        unquote(__MODULE__).__define_message_function__(extension, function_name, fallback_function)
      end

      unquote(__MODULE__).__define_fallback_module__(extension, functions)
    end
  end

  @doc false
  defmacro __define_message_function__(extension, function_name, fallback_function) do
    quote bind_quoted: [extension: extension, function_name: function_name, fallback_function: fallback_function] do
      def unquote(function_name)(conn) do
        unquote(extension).unquote(fallback_function)(conn)
      end

      defoverridable [{function_name, 1}]
    end
  end

  @doc false
  defmacro __define_fallback_module__(extension, functions) do
    quote do
      name   = Module.concat([__MODULE__, unquote(extension)])
      quoted = for {function, 1} <- unquote(functions) do
        function_name = unquote(__MODULE__).Helpers.function_name(unquote(extension), function)

        quote do
          def unquote(function)(conn) do
            unquote(__MODULE__).unquote(function_name)(conn)
          end
        end
      end

      Module.create(name, quoted, Macro.Env.location(__ENV__))
    end
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "No longer public function"
  def method_name(extension, type), do: Helpers.function_name(extension, type)
end
