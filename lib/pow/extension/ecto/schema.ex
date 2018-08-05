defmodule Pow.Extension.Ecto.Schema do
  @moduledoc """
  Handles extensions for the user Ecto schema.

  ## Usage

  Configure `lib/my_project/users/user.ex` the following way:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema
        use Pow.Extension.Ecto.Schema,
          extensions: [PowExtensionOne, PowExtensionTwo]

        schema "users" do
          pow_user_fields()

          timestamps()
        end

        def changeset(user_or_changeset, attrs) do
          user
          |> pow_changeset(attrs)
          |> pow_extension_changeset(attrs)
        end
      end
  """
  alias Ecto.Changeset
  alias Pow.{Config, Extension}

  defmodule SchemaError do
    defexception [:message]
  end

  defmacro __using__(config) do
    quote do
      @pow_extension_config Config.merge(@pow_config, unquote(config))

      unquote(__MODULE__).__register_extension_fields__()
      unquote(__MODULE__).__pow_extension_methods__()
      unquote(__MODULE__).__register_after_compile_validation__()
    end
  end

  @spec __register_extension_fields__() :: Macro.t()
  defmacro __register_extension_fields__ do
    quote do
      config = Module.get_attribute(__MODULE__, :pow_extension_config)
      extension_attrs = unquote(__MODULE__).attrs(config)

      for attr <- extension_attrs do
        Module.put_attribute(__MODULE__, :pow_fields, attr)
      end
    end
  end

  @spec __pow_extension_methods__() :: Macro.t()
  defmacro __pow_extension_methods__ do
    quote do
      @spec pow_extension_changeset(Changeset.t(), map()) :: Changeset.t()
      def pow_extension_changeset(changeset, attrs) do
        unquote(__MODULE__).changeset(changeset, attrs, @pow_extension_config)
      end
    end
  end

  @spec __register_after_compile_validation__() :: Macro.t()
  defmacro __register_after_compile_validation__ do
    quote do
      def validate_after_compilation!(env, _bytecode) do
        unquote(__MODULE__).validate!(@pow_extension_config, __MODULE__)
      end

      @after_compile {__MODULE__, :validate_after_compilation!}
    end
  end

  @spec attrs(Config.t()) :: [tuple]
  def attrs(config) do
    config
    |> __schema_extensions__()
    |> Enum.reduce([], fn extension, attrs ->
      extension_attrs = extension.attrs(config)

      Enum.concat(attrs, extension_attrs)
    end)
  end

  @spec indexes(Config.t()) :: [tuple]
  def indexes(config) do
    config
    |> __schema_extensions__()
    |> Enum.reduce([], fn extension, indexes ->
      extension_indexes = extension.indexes(config)

      Enum.concat(indexes, extension_indexes)
    end)
  end

  @spec changeset(Changeset.t(), map(), Config.t()) :: Changeset.t()
  def changeset(changeset, attrs, config) do
    config
    |> __schema_extensions__()
    |> Enum.reduce(changeset, fn extension, changeset ->
      extension.changeset(changeset, attrs, config)
    end)
  end

  @spec validate!(Config.t(), atom()) :: :ok | no_return
  def validate!(config, module) do
    config
    |> __schema_extensions__()
    |> Enum.each(&(&1.validate!(config, module)))

    :ok
  end

  @spec __schema_extensions__(Config.t()) :: [atom()]
  def __schema_extensions__(config) do
    Extension.Config.discover_modules(config, ["Ecto", "Schema"])
  end

  @spec require_schema_field!(atom(), atom(), atom()) :: :ok | no_return
  def require_schema_field!(module, field, extension) do
    fields = module.__schema__(:fields)

    fields
    |> Enum.member?(field)
    |> case do
      true  -> :ok
      false -> raise_missing_field_error(module, field, extension)
    end
  end

  defp raise_missing_field_error(module, field, extension) do
    raise SchemaError, message: "A `#{inspect field}` schema field should be defined in #{inspect module} to use #{inspect extension}"
  end
end
