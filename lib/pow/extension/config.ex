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

  # TODO: Remove by 1.1.0
  @deprecated "Use `extension_modules/2` instead"
  def discover_modules(config, module_list) do
    config
    |> extensions()
    |> extension_modules(module_list)
  end

  # TODO: Remove by 1.1.0
  @doc """
  Returns a binary of the extension atom.

  This is usually used to create extension namespaces for functions to be used
  in shared modules.
  """
  @deprecated "Create the namespace directly in your module"
  @spec underscore_extension(atom()) :: binary()
  def underscore_extension(extension) do
    extension
    |> Module.split()
    |> List.first()
    |> Macro.underscore()
  end
end
