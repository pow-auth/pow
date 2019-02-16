defmodule Pow.Ecto.Schema do
  @moduledoc """
  Handles the Ecto schema for user.

  The macro will create a `:pow_fields` module attribute, and append fields
  to it. The `pow_user_fields/0` macro will use these attributes to create
  fields in the ecto schema.

  A default `changeset/2` method is created, but can be overridden with a
  custom `changeset/2` method.

  ## Usage

  Configure `lib/my_project/users/user.ex` the following way:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema,
          user_id_field: :email,
          password_hash_methods: {&Pow.Ecto.Schema.Password.pbkdf2_hash/1,
                                  &Pow.Ecto.Schema.Password.pbkdf2_verify/2},
          password_min_length: 10,
          password_max_length: 4096

        schema "users" do
          field :custom_field, :string

          pow_user_fields()

          timestamps()
        end

        def changeset(user_or_changeset, attrs) do
          pow_changeset(user, attrs)
        end
      end

  Remember to add `user: MyApp.Users.User` to your configuration.

  ## Customize Pow fields

  Pow fields can be overridden if the field name and type matches:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema

        schema "users" do
          field :encrypted_password, :string
          field :password_hash, :string, source: :encrypted_password

          pow_user_fields()

          timestamps()
        end
      end

  ## Customize Pow changeset

  You can extract individual changeset methods to modify the changeset
  flow entirely. As an example, this  is how you can remove the validation
  check for confirm password in the changeset method:

      defmodule MyApp.Users.User do
        # ...

        import Pow.Ecto.Schema.Changeset, only: [new_password_changeset: 3]

        # ...

        def changeset(user_or_changeset, attrs) do
          user_or_changeset
          |> pow_user_id_field_changeset(attrs)
          |> pow_current_password_changeset(attrs)
          |> new_password_changeset(attrs, @pow_config)
        end
      end

  ## Configuration options

    * `:user_id_field` - the field to use for user id. This value defaults to
      `:email`, and the changeset will automatically validate it as an e-mail.
  """
  alias Ecto.Changeset
  alias Pow.Config

  @callback changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  @callback verify_password(Ecto.Schema.t(), binary()) :: boolean()

  @doc false
  defmacro __using__(config) do
    quote do
      @behaviour unquote(__MODULE__)
      @pow_config unquote(config)

      @spec changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
      def changeset(user_or_changeset, attrs), do: pow_changeset(user_or_changeset, attrs)

      @spec verify_password(Ecto.Schema.t(), binary()) :: boolean()
      def verify_password(user, password), do: pow_verify_password(user, password)

      defoverridable unquote(__MODULE__)

      unquote(__MODULE__).__pow_methods__()
      unquote(__MODULE__).__register_fields__()
      unquote(__MODULE__).__register_user_id_field__()
    end
  end

  @changeset_methods [:user_id_field_changeset, :password_changeset, :current_password_changeset]

  @doc false
  defmacro __pow_methods__ do
    quoted_changeset_methods =
      for method <- @changeset_methods do
        pow_method_name = String.to_atom("pow_#{method}")

        quote do
          @spec unquote(pow_method_name)(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
          def unquote(pow_method_name)(user_or_changeset, attrs) do
            unquote(__MODULE__).Changeset.unquote(method)(user_or_changeset, attrs, @pow_config)
          end
        end
      end

    quote do
      import unquote(__MODULE__), only: [pow_user_fields: 0]

      @spec pow_changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
      def pow_changeset(user_or_changeset, attrs) do
        user_or_changeset
        |> pow_user_id_field_changeset(attrs)
        |> pow_current_password_changeset(attrs)
        |> pow_password_changeset(attrs)
      end

      unquote(quoted_changeset_methods)

      @spec pow_verify_password(Ecto.Schema.t(), binary()) :: boolean()
      def pow_verify_password(user, password) do
        unquote(__MODULE__).Changeset.verify_password(user, password, @pow_config)
      end
    end
  end

  @doc """
  A macro to add fields from the `@pow_fields` module attribute generated in
  `__using__/1`.
  """
  defmacro pow_user_fields do
    quote do
      @pow_fields
      |> unquote(__MODULE__).filter_new_fields(@ecto_fields)
      |> Enum.each(fn
        {name, type} ->
          field(name, type)

        {name, type, defaults} ->
          field(name, type, defaults)
      end)
    end
  end

  @doc false
  defmacro __register_fields__ do
    quote do
      Module.register_attribute(__MODULE__, :pow_fields, accumulate: true)

      for attr <- unquote(__MODULE__).Fields.attrs(@pow_config) do
        Module.put_attribute(__MODULE__, :pow_fields, attr)
      end
    end
  end

  @doc false
  defmacro __register_user_id_field__ do
    quote do
      @user_id_field unquote(__MODULE__).user_id_field(@pow_config)
      def pow_user_id_field, do: @user_id_field
    end
  end

  @doc """
  Get user id field key from configuration.

  Defaults to `:email`.
  """
  @spec user_id_field(Config.t()) :: atom()
  def user_id_field(config \\ []), do: Config.get(config, :user_id_field, :email)

  @doc """
  Normalizes the user id field.

  Keeps the user id field value case insensitive and removes leading and
  trailing whitespace.
  """
  @spec normalize_user_id_field_value(binary()) :: binary()
  def normalize_user_id_field_value(value) do
    value
    |> String.trim()
    |> String.downcase()
  end

  @doc """
  Filters field-type pairs that doesn't already exist in schema.
  """
  @spec filter_new_fields([tuple()], [tuple()]) :: [tuple()]
  def filter_new_fields(fields, existing_fields) when is_list(fields) do
    Enum.filter(fields, &not Enum.member?(existing_fields, {elem(&1, 0), elem(&1, 1)}))
  end

  @doc false
  def __timestamp_for__(struct, column) do
    type = struct.__schema__(:type, column)

    __timestamp__(type)
  end

  @doc false
  def __timestamp__(:naive_datetime) do
    %{NaiveDateTime.utc_now() | microsecond: {0, 0}}
  end
  def __timestamp__(:naive_datetime_usec) do
    NaiveDateTime.utc_now()
  end
  def __timestamp__(:utc_datetime) do
    DateTime.from_unix!(System.system_time(:second), :second)
  end
  def __timestamp__(:utc_datetime_usec) do
    DateTime.from_unix!(System.system_time(:microsecond), :microsecond)
  end
  def __timestamp__(type) do
    type.from_unix!(System.system_time(:microsecond), :microsecond)
  end
end
