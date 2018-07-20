defmodule Pow.Ecto.Schema do
  @moduledoc """
  Handles the Ecto schema for user.

  ## Usage

  Configure `lib/my_project/user/user.ex` the following way:

      defmodule MyApp.Users.User do
        use Ecto.Schema
        use Pow.Ecto.Schema,
          login_field: :email,
          password_hash_methods: {&Pow.Ecto.Schema.Changeset.pbkdf2_hash/1,
                                  &Pow.Ecto.Schema.Changeset.pbkdf2_verify/2}

        schema "users" do
          field :custom_field, :string

          pow_user_fields()

          timestamps()
        end

        def changeset(user_or_changeset, attrs) do
          pow_changeset(user, attrs)
        end
      end

  Remember to add `user: MyApp.Users.User` to configuration.
  """
  alias Pow.Config

  @callback changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  @callback verify_password(Ecto.Schema.t(), binary()) :: boolean()

  defmacro __using__(config) do
    quote do
      @behaviour unquote(__MODULE__)

      def changeset(user, attrs), do: pow_changeset(user, attrs)
      def verify_password(user, password), do: pow_verify_password(user, password)

      defoverridable unquote(__MODULE__)

      unquote(__MODULE__).pow_methods(unquote(config))
      unquote(__MODULE__).register_fields(unquote(config))
      unquote(__MODULE__).register_login_field(unquote(config))
    end
  end

  @spec pow_methods(Config.t()) :: Macro.t()
  defmacro pow_methods(config) do
    quote do
      import unquote(__MODULE__), only: [pow_user_fields: 0]

      def pow_changeset(user, attrs) do
        unquote(__MODULE__).Changeset.changeset(unquote(config), user, attrs)
      end

      def pow_verify_password(user, password) do
        unquote(__MODULE__).Changeset.verify_password(user, password, unquote(config))
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

  @spec register_fields(Config.t()) :: Macro.t()
  defmacro register_fields(config) do
    quote do
      Module.register_attribute(__MODULE__, :pow_fields, accumulate: true)
      for attr <- unquote(__MODULE__).Fields.attrs(unquote(config)) do
        Module.put_attribute(__MODULE__, :pow_fields, attr)
      end
    end
  end

  @spec register_login_field(Config.t()) :: Macro.t()
  defmacro register_login_field(config) do
    quote do
      @login_field unquote(__MODULE__).login_field(unquote(config))
      def pow_login_field(), do: @login_field
    end
  end

  @spec login_field() :: atom()
  def login_field(), do: :email

  @spec login_field(Keyword.t()) :: atom()
  def login_field(config) when is_list(config), do: Config.get(config, :login_field, login_field())

  @spec login_field(module()) :: atom()
  def login_field(module), do: module.pow_login_field()
end
