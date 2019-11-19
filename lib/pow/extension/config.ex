defmodule Pow.Extension.Config do
  @moduledoc """
  Configuration helpers for extensions.
  """
  alias Pow.Config

  @doc """
  Fetches the `:extensions` key from the configuration.
  """
  @spec extensions(Config.t()) :: [atom()]
  def extensions(config) do
    Config.get(config, :extensions, [])
  end

  # This speeds up compile since we won't depend on `Code.ensure_compiled?/1`
  @compiled_modules [
    PowEmailConfirmation.Ecto.Schema,
    PowEmailConfirmation.Phoenix.ControllerCallbacks,
    PowEmailConfirmation.Phoenix.Messages,
    PowEmailConfirmation.Phoenix.Router,
    PowInvitation.Ecto.Schema,
    PowInvitation.Phoenix.Messages,
    PowInvitation.Phoenix.Router,
    PowPersistentSession.Phoenix.ControllerCallbacks,
    PowResetPassword.Ecto.Schema,
    PowResetPassword.Phoenix.Messages,
    PowResetPassword.Phoenix.Router,
  ]

  @doc """
  Finds all existing extension modules that matches the extensions and module
  list.

  This will iterate through all extensions appending the module list to the
  extension module and return a list of all modules that exists in the project.
  """
  @spec extension_modules([atom()], [any()]) :: [atom()]
  def extension_modules(extensions, module_list) do
    extensions
    |> Enum.map(&Module.concat([&1] ++ module_list))
    |> Enum.filter(fn
      module when module in @compiled_modules -> true
      module -> Code.ensure_compiled?(module)
    end)
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

  This is usually used to create extension namespaces for methods to be used
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
