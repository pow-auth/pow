defmodule Pow.Extension.Phoenix.Controller.Base do
  @moduledoc """
  Used with Pow Extension Phoenix controllers to handle messages and routes.

  ## Usage

      defmodule MyPowExtension.Phoenix.CustomController do
        use Pow.Extension.Phoenix.Controller.Base

        # ...
      end
  """
  alias Pow.{Config, Phoenix.Controller}

  @doc false
  defmacro __using__(config) do
    quote do
      use Controller, unquote(config)

      unquote(__MODULE__).__define_helper_methods__(unquote(config))
    end
  end

  @doc false
  defmacro __define_helper_methods__(config) do
    quote do
      @messages_fallback unquote(__MODULE__).__messages_fallback__(unquote(config), __MODULE__, __ENV__)

      @doc false
      def extension_messages(conn), do: unquote(__MODULE__).__messages_module__(conn, @messages_fallback)

      @routes_fallback unquote(__MODULE__).__routes_fallback__(__MODULE__)

      @doc false
      def extension_routes(conn), do: unquote(__MODULE__).__routes_module__(conn, @routes_fallback)
    end
  end

  @doc false
  def __messages_module__(conn, fallback) do
    case Controller.messages(conn, fallback) do
      ^fallback -> fallback
      messages  -> Module.concat([messages, fallback])
    end
  end

  @doc false
  def __messages_fallback__(module), do: fallback(module, Messages)

  # TODO: Remove config fallback by 1.1.0
  def __messages_fallback__(config, module, env) do
    case Config.get(config, :messages_backend_fallback) do
      nil    ->
        __messages_fallback__(module)

      module ->
        IO.warn("Passing `:messages_backend_fallback` is deprecated", Macro.Env.stacktrace(env))

        module
    end
  end

  @doc false
  def __routes_fallback__(module), do: fallback(module, Routes)

  @doc false
  def __routes_module__(conn, fallback) do
    case Controller.routes(conn, fallback) do
      ^fallback -> fallback
      routes    -> Module.concat([routes, fallback])
    end
  end

  defp fallback(controller, module) do
    [_controller | base] =
      controller
      |> Module.split()
      |> Enum.reverse()

    [module]
    |> Enum.concat(base)
    |> Enum.reverse()
    |> Module.concat()
  end
end
