defmodule Authex.Ecto.Schema do
  @moduledoc """
  Handles the Ecto schema for user.

  ## Usage

  Configure `lib/my_project/user/user.ex` the following way:

      defmodule MyProject.Users.User do
        use Ecto.Schema
        use Authex.Ecto.Schema,
          login_field: :email,
          password_hash_methods: {&Authex.Ecto.Schema.Changeset.pbkdf2_hash/1,
                                  &Authex.Ecto.Schema.Changeset.pbkdf2_verify/2}

        schema "users" do
          field :custom_field, :string

          user_fields()

          timestamps()
        end

        def changeset(user_or_changeset, attrs) do
          authex_changeset(user, attrs)
        end
      end

  Remember to add `user: MyProject.Users.User` to configuration.
  """
  alias Authex.{Config, Ecto.Schema.Fields}

  @callback changeset(Ecto.Schema.t() | Changeset.t(), map()) :: Changeset.t()
  @callback verify_password(Ecto.Schema.t(), binary()) :: boolean()

  defmacro __using__(config) do
    quote do
      alias Authex.Ecto.Schema.Changeset
      import unquote(__MODULE__), only: [user_fields: 0]
      @behaviour unquote(__MODULE__)

      @authex_login_field unquote(__MODULE__).login_field(unquote(config))
      def authex_login_field(), do: @authex_login_field

      def changeset(user, attrs), do: authex_changeset(user, attrs)
      def verify_password(user, password), do: authex_verify_password(user, password)

      def authex_changeset(user, attrs) do
        Changeset.changeset(unquote(config), user, attrs)
      end

      def authex_verify_password(user, password) do
        Changeset.verify_password(user, password, unquote(config))
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @spec user_fields() :: Macro.t()
  defmacro user_fields() do
    quote do
      attrs =
        @authex_login_field
        |> Fields.attrs()
        |> Enum.map(fn
          {name, type} -> %{name: name, type: type, defaults: []}
          {name, type, defaults} -> %{name: name, type: type, defaults: defaults}
        end)

      for %{name: name, type: type, defaults: defaults} <- attrs do
        field(name, type, defaults)
      end
    end
  end

  @spec login_field() :: atom()
  def login_field(), do: :email

  @spec login_field(Keyword.t()) :: atom()
  def login_field(config) when is_list(config), do: Config.get(config, :login_field, login_field())

  @spec login_field(module()) :: atom()
  def login_field(module), do: module.authex_login_field()
end
