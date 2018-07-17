defmodule Authex.Extension.Ecto.Schema do
  @moduledoc """
  Handles extensions for the user Ecto schema.

  ## Usage

  Configure `lib/my_project/user/user.ex` the following way:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Authex.Ecto.Schema
        use Authex.Extension.Ecto.Schema,
          extensions: [AuthexExtensionOne, AuthexExtensionTwo]

        schema "users" do
          authex_user_fields()

          timestamps()
        end

        def changeset(user_or_changeset, attrs) do
          user
          |> authex_changeset(attrs)
          |> authex_extension_changeset(attrs)
        end
      end
  """
  alias Authex.{Config, Extension}
  alias Ecto.Changeset

  defmacro __using__(config) do
    quote do
      unquote(__MODULE__).register_extension_fields(unquote(config))
      unquote(__MODULE__).authex_extension_methods(unquote(config))
    end
  end

  @spec register_extension_fields(Config.t()) :: Macro.t()
  defmacro register_extension_fields(config) do
    quote do
      login_field = Module.get_attribute(__MODULE__, :login_field)
      for attr <- unquote(__MODULE__).attrs(unquote(config), login_field) do
        Module.put_attribute(__MODULE__, :authex_fields, attr)
      end
    end
  end

  @spec authex_extension_methods(Config.t()) :: Macro.t()
  defmacro authex_extension_methods(config) do
    quote do
      def authex_extension_changeset(changeset, attrs) do
        unquote(__MODULE__).changeset(changeset, attrs, unquote(config))
      end
    end
  end

  @spec attrs(Config.t(), atom()) :: [tuple]
  def attrs(config, login_field) do
    reduce(config, fn extension, attrs ->
      extension_attrs =
        config
        |> extension.validate!(login_field)
        |> extension.attrs()

      Enum.concat(attrs, extension_attrs)
    end)
  end

  @spec indexes(Config.t()) :: [tuple]
  def indexes(config) do
    reduce(config, fn extension, indexes ->
      extension_indexes = extension.indexes(config)
      Enum.concat(indexes, extension_indexes)
    end)
  end

  @spec changeset(Changeset.t(), map(), Config.t()) :: Changeset.t()
  def changeset(changeset, attrs, config) do
    reduce(config, changeset, fn extension, changeset ->
      extension.changeset(changeset, attrs, config)
    end)
  end

  defp reduce(config, method), do: reduce(config, [], method)
  defp reduce(config, acc, method) do
    config
    |> Extension.Config.extensions()
    |> Enum.map(&to_schema_extension/1)
    |> Enum.reduce(acc, method)
  end

  defp to_schema_extension(extension) do
    module = Module.concat([extension, "Ecto", "Schema"])

    module
    |> Code.ensure_compiled?()
    |> case do
      true -> module
      false -> nil
    end
  end
end
