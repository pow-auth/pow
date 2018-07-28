defmodule Pow.Ecto.Schema do
  @moduledoc """
  Handles the Ecto schema for user.

  ## Usage

  Configure `lib/my_project/users/user.ex` the following way:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema,
          user_id_field: :email,
          password_hash_methods: {&Pow.Ecto.Schema.Changeset.pbkdf2_hash/1,
                                  &Pow.Ecto.Schema.Changeset.pbkdf2_verify/2},
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

  ## Configuration options

    * `:user_id_field` the field to use for user id, defaults to :email, and will
      be validated as an email
  """
  alias Pow.Config
  alias Ecto.Changeset

  @callback changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  @callback verify_password(Ecto.Schema.t(), binary()) :: boolean()

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

  @spec __pow_methods__() :: Macro.t()
  defmacro __pow_methods__() do
    quote do
      import unquote(__MODULE__), only: [pow_user_fields: 0]

      @spec pow_changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
      def pow_changeset(user_or_changeset, attrs) do
        unquote(__MODULE__).Changeset.changeset(@pow_config, user_or_changeset, attrs)
      end

      @spec pow_verify_password(Ecto.Schema.t(), binary()) :: boolean()
      def pow_verify_password(user, password) do
        unquote(__MODULE__).Changeset.verify_password(user, password, @pow_config)
      end
    end
  end

  @spec pow_user_fields :: Macro.t()
  defmacro pow_user_fields do
    quote do
      Enum.each(@pow_fields, fn
        {name, type} ->
          field(name, type)

        {name, type, defaults} ->
          field(name, type, defaults)
      end)
    end
  end

  @spec __register_fields__() :: Macro.t()
  defmacro __register_fields__() do
    quote do
      Module.register_attribute(__MODULE__, :pow_fields, accumulate: true)
      for attr <- unquote(__MODULE__).Fields.attrs(@pow_config) do
        Module.put_attribute(__MODULE__, :pow_fields, attr)
      end
    end
  end

  @spec __register_user_id_field__() :: Macro.t()
  defmacro __register_user_id_field__() do
    quote do
      @user_id_field unquote(__MODULE__).user_id_field(@pow_config)
      def pow_user_id_field, do: @user_id_field
    end
  end

  @spec user_id_field :: atom()
  def user_id_field, do: :email

  @spec user_id_field(Config.t() | Changeset.t() | map() | atom()) :: atom()
  def user_id_field(config) when is_list(config), do: Config.get(config, :user_id_field, user_id_field())
  def user_id_field(%Changeset{data: data}), do: user_id_field(data.__struct__)
  def user_id_field(map) when is_map(map), do: user_id_field(map.__struct__)
  def user_id_field(module), do: module.pow_user_id_field()

  @spec normalize_user_id_field_value(binary()) :: binary()
  def normalize_user_id_field_value(value), do: String.downcase(value)
end
