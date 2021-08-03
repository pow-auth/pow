defmodule Pow.Extension.Base do
  @moduledoc """
  Used to set up extensions to enable parts of extension for auto-discovery.

  This exists to prevent unnecessary `Code.ensure_compiled/1` calls, and will
  let the extension define what modules it has.

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
  @callback phoenix_templates() :: [{binary(), [binary()]}]

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

      @doc false
      @impl true
      def phoenix_templates(), do: []

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Checks whether an extension has a certain module.

  If a base extension module doesn't exist, or is configured improperly,
  `Code.ensure_compiled/1` will be used instead to see whether the module
  exists for the extension.
  """
  @spec has?(atom(), [any()]) :: boolean()
  def has?(extension, module_list) do
    try do
      has_extension_module?(extension, module_list)
    rescue
      # TODO: Remove or refactor by 1.1.0
      _e in UndefinedFunctionError ->
        IO.warn("no #{inspect extension} base module to check for #{inspect module_list} support found, please use #{inspect __MODULE__} to implement it")

        [extension]
        |> Kernel.++(module_list)
        |> Module.concat()
        |> ensure_compiled?()
    end
  end

  defp ensure_compiled?(module), do: match?({:module, ^module}, Code.ensure_compiled(module))

  defp has_extension_module?(extension, ["Ecto", "Schema"]), do: extension.ecto_schema?()
  defp has_extension_module?(extension, ["Phoenix", "ControllerCallbacks"]), do: extension.phoenix_controller_callbacks?()
  defp has_extension_module?(extension, ["Phoenix", "Messages"]), do: extension.phoenix_messages?()
  defp has_extension_module?(extension, ["Phoenix", "Router"]), do: extension.phoenix_router?()

  @doc """
  Checks whether an extension has a certain module that has a `__using__/1`
  macro.

  This calls `has?/2` first, If a base extension module doesn't exist, or is
  configured improperly, `Kernel.macro_exported?/3` will be used instead to
  check if the module has a `__using__/1` macro.
  """
  @spec use?(atom(), [any()]) :: boolean()
  def use?(extension, module_list) do
    case has?(extension, module_list) do
      true  ->
        try do
          use_extension_module?(extension, module_list)
        rescue
          # TODO: Remove or refactor by 1.1.0
          _e in UndefinedFunctionError ->
            IO.warn("#{inspect extension} has been configured improperly")

            [extension]
            |> Kernel.++(module_list)
            |> Module.concat()
            |> Kernel.macro_exported?(:__using__, 1)
        end

      false ->
        false
    end
  end

  defp use_extension_module?(extension, ["Ecto", "Schema"]), do: extension.use_ecto_schema?()
end
