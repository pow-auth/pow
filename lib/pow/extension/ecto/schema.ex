defmodule Pow.Extension.Ecto.Schema do
  @moduledoc """
  Handles extensions for the user Ecto schema.

  The macro will append fields to the `@pow_fields` module attribute using the
  attributes from `[Pow Extension].Ecto.Schema.attrs/1`, so they can be used in
  the `Pow.Ecto.Schema.pow_user_fields/0` function call.

  After module compilation `[Pow Extension].Ecto.Schema.validate!/2` will run.

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
  alias Pow.{Config, Extension, Extension.Base}

  defmodule SchemaError do
    @moduledoc false
    defexception [:message]
  end

  @doc false
  defmacro __using__(config) do
    quote do
      @pow_extension_config Config.merge(@pow_config, unquote(config))

      Module.eval_quoted(__MODULE__, unquote(__MODULE__).__use_extensions__(@pow_extension_config))

      unquote(__MODULE__).__register_extension_fields__()
      unquote(__MODULE__).__register_extension_assocs__()
      unquote(__MODULE__).__pow_extension_functions__()
      unquote(__MODULE__).__register_after_compile_validation__()
    end
  end

  @doc false
  def __use_extensions__(config) do
    config
    |> schema_modules_with_use()
    |> Enum.map(fn module ->
      quote do
        use unquote(module), unquote(config)
      end
    end)
  end

  @doc false
  defmacro __register_extension_fields__ do
    quote do
      for {name, value, options, _migration_options} <- unquote(__MODULE__).attrs(@pow_extension_config) do
        Module.put_attribute(__MODULE__, :pow_fields, {name, value, options})
      end
    end
  end

  @doc false
  defmacro __register_extension_assocs__ do
    quote do
      @pow_extension_config
      |> unquote(__MODULE__).assocs()
      |> Enum.map(fn
        {type, name, :users, field_options, _migration_options} -> {type, name, __MODULE__, field_options}
        {type, name, module, field_options, _migration_options} -> {type, name, module, field_options}
      end)
      |> Enum.each(&Module.put_attribute(__MODULE__, :pow_assocs, &1))
    end
  end

  @doc false
  defmacro __pow_extension_functions__ do
    quote do
      def pow_extension_changeset(changeset, attrs) do
        unquote(__MODULE__).changeset(changeset, attrs, @pow_extension_config)
      end
    end
  end

  @doc false
  defmacro __register_after_compile_validation__ do
    quote do
      def pow_extension_validate_after_compilation!(env, _bytecode) do
        unquote(__MODULE__).validate!(@pow_extension_config, __MODULE__)
      end

      @after_compile {__MODULE__, :pow_extension_validate_after_compilation!}
    end
  end

  @doc """
  Merge all extension attributes together to one list.

  The extension ecto schema modules is discovered through the `:extensions` key
  in the configuration, and the attribute list will be in the same order as the
  extensions list.
  """
  @spec attrs(Config.t()) :: [tuple]
  def attrs(config) do
    config
    |> schema_modules()
    |> Enum.reduce([], fn extension, attrs ->
      extension_attrs = extension.attrs(config)

      Enum.concat(attrs, extension_attrs)
    end)
    |> Enum.map(&normalize_attr/1)
  end

  defp normalize_attr({name, value}), do: {name, value, [], []}
  defp normalize_attr({name, value, field_options}), do: {name, value, field_options, []}
  defp normalize_attr({name, value, field_options, migration_options}), do: {name, value, field_options, migration_options}

  @doc """
  Merge all extension associations together to one list.

  The extension ecto schema modules is discovered through the `:extensions` key
  in the configuration, and the attribute list will be in the same order as the
  extensions list.
  """
  @spec assocs(Config.t()) :: [tuple]
  def assocs(config) do
    config
    |> schema_modules()
    |> Enum.reduce([], fn extension, assocs ->
      extension_assocs = extension.assocs(config)

      Enum.concat(assocs, extension_assocs)
    end)
    |> Enum.map(&normalize_assoc/1)
  end

  defp normalize_assoc({type, name, module}), do: {type, name, module, [], []}
  defp normalize_assoc({type, name, module, field_options}), do: {type, name, module, field_options, []}
  defp normalize_assoc({type, name, module, field_options, migration_options}), do: {type, name, module, field_options, migration_options}

  @doc """
  Merge all extension indexes together to one list.

  The extension ecto schema modules is discovered through the `:extensions` key
  in the configuration, and the index list will be in the same order as the
  extensions list.
  """
  @spec indexes(Config.t()) :: [tuple]
  def indexes(config) do
    config
    |> schema_modules()
    |> Enum.reduce([], fn extension, indexes ->
      extension_indexes = extension.indexes(config)

      Enum.concat(indexes, extension_indexes)
    end)
  end

  @doc """
  This will run `changeset/3` on all extension ecto schema modules.

  The extension ecto schema modules is discovered through the `:extensions` key
  in the configuration, and the changesets will be piped in the same order
  as the extensions list.
  """
  @spec changeset(Changeset.t(), map(), Config.t()) :: Changeset.t()
  def changeset(changeset, attrs, config) do
    config
    |> schema_modules()
    |> Enum.reduce(changeset, fn extension, changeset ->
      extension.changeset(changeset, attrs, config)
    end)
  end

  @doc """
  This will run `validate!/2` on all extension ecto schema modules.

  It's used to ensure certain fields are available, e.g. an `:email` field. The
  function should either raise an exception, or return `:ok`. Compilation will
  fail when the exception is raised.
  """
  @spec validate!(Config.t(), atom()) :: :ok
  def validate!(config, module) do
    config
    |> schema_modules()
    |> Enum.each(& &1.validate!(config, module))

    :ok
  end

  defp schema_modules(config) do
    config
    |> Extension.Config.extensions()
    |> Extension.Config.extension_modules(["Ecto", "Schema"])
  end

  defp schema_modules_with_use(config) do
    config
    |> Extension.Config.extensions()
    |> Enum.filter(&Base.use?(&1, ["Ecto", "Schema"]))
    |> Enum.map(&Module.concat([&1] ++ ["Ecto", "Schema"]))
  end

  @doc """
  Validates that the ecto schema has the specified field.

  If the field doesn't exist, it'll raise an exception.
  """
  @spec require_schema_field!(atom(), atom(), atom()) :: :ok
  def require_schema_field!(module, field, extension) do
    fields = module.__schema__(:fields)

    fields
    |> Enum.member?(field)
    |> case do
      true  -> :ok
      false -> raise_missing_field_error!(module, field, extension)
    end
  end

  @spec raise_missing_field_error!(module(), atom(), atom()) :: no_return()
  defp raise_missing_field_error!(module, field, extension),
    do: raise SchemaError, message: "A `#{inspect field}` schema field should be defined in #{inspect module} to use #{inspect extension}"
end
