defmodule Pow.Extension.Phoenix.Controller.Base do
  @moduledoc """
  Used with Pow Extension Phoenix controllers to handle messages and routes.

  ## Usage

      defmodule MyPowExtension.Phoenix.CustomController do
        use Pow.Extension.Phoenix.Controller.Base

        # ...
      end
  """
  alias Pow.Phoenix.Controller

  @doc false
  defmacro __using__(config) do
    quote do
      use Controller, unquote(config)

      unquote(__MODULE__).__define_helper_methods__()
    end
  end

  @doc false
  defmacro __define_helper_methods__() do
    quote do
      @messages_fallback unquote(__MODULE__).__messages_fallback__(__MODULE__)

      @doc false
      def extension_messages(conn), do: unquote(__MODULE__).__messages_module__(conn, @messages_fallback)
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
  def __messages_fallback__(module) do
    [_controller | base] =
      module
      |> Module.split()
      |> Enum.reverse()

    [Messages]
    |> Enum.concat(base)
    |> Enum.reverse()
    |> Module.concat()
  end
end
