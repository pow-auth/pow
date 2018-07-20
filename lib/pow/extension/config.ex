defmodule Pow.Extension.Config do
  @moduledoc """
  Configuration helpers for extensions.
  """
  alias Pow.Config

  @spec extensions(Config.t()) :: [atom()]
  def extensions(config) do
    Config.get(config, :extensions, [])
  end

  @spec discover_modules(Config.t(), [any()]) :: [atom()]
  def discover_modules(config, module_list) do
    config
    |> extensions()
    |> Enum.map(&Module.concat([&1] ++ module_list))
    |> Enum.filter(&Code.ensure_compiled?/1)
    |> Enum.reject(&is_nil/1)
  end

  @spec underscore_extension(atom()) :: binary()
  def underscore_extension(extension) do
    extension
    |> Module.split()
    |> List.first()
    |> Macro.underscore()
  end
end
