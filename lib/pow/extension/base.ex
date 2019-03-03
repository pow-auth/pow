defmodule Pow.Extension.Base do
  @moduledoc """
  Used to set up extensions to enable parts of extension for auto-discovery.

  ## Usage

      defmodule MyCustomExtension do
        use Pow.Extension.Base

        @impl true
        def ecto_schema?(), do: true
      end
  """
  @callback ecto_schema?() :: boolean()
  @callback use_ecto_schema?() :: boolean()
  @callback phoenix_controller_callbacks?() :: boolean()
  @callback phoenix_messages?() :: boolean()
  @callback phoenix_router?() :: boolean()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @doc false
      @impl true
      def ecto_schema?(), do: false

      @doc false
      @impl true
      def use_ecto_schema?(), do: false

      @doc false
      @impl true
      def phoenix_controller_callbacks?(), do: false

      @doc false
      @impl true
      def phoenix_messages?(), do: false

      @doc false
      @impl true
      def phoenix_router?(), do: false

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Checks whether an extension has a certain module.
  """
  @spec has?(atom(), [any()]) :: boolean()
  def has?(extension, ["Ecto", "Schema"]), do: extension.ecto_schema?()
  def has?(extension, ["Phoenix", "ControllerCallbacks"]), do: extension.phoenix_controller_callbacks?()
  def has?(extension, ["Phoenix", "Messages"]), do: extension.phoenix_messages?()
  def has?(extension, ["Phoenix", "Router"]), do: extension.phoenix_router?()

  @doc """
  Checks whether an extension has a certain module that has a `__using__/1`
  macro.
  """
  @spec use?(atom(), [any()]) :: boolean()
  def use?(extension, module_list) do
    case has?(extension, module_list) do
      true  -> use_extension_module?(extension, module_list)
      false -> false
    end
  end

  defp use_extension_module?(extension, ["Ecto", "Schema"]), do: extension.use_ecto_schema?()
end
