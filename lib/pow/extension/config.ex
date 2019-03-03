defmodule Pow.Extension.Config do
  @moduledoc """
  Configuration helpers for extensions.
  """
  alias Pow.{Config, Extension.Base}

  @doc """
  Fetches the `:extensions` key from the configuration.
  """
  @spec extensions(Config.t()) :: [atom()]
  def extensions(config) do
    Config.get(config, :extensions, [])
  end

  @doc """
  Finds all existing extension modules that matches the extensions and module
  list.

  This will iterate through all extensions appending the module list to the
  extension module and return a list of all modules that exists in the project.
  """
  @spec extension_modules([atom()], [any()]) :: [atom()]
  def extension_modules(extensions, module_list) do
    extensions
    |> Enum.filter(&Base.has?(&1, module_list))
    |> Enum.map(&Module.concat([&1] ++ module_list))
  end
end
