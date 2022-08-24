defmodule Pow.Extension.Ecto.SchemaTest do
  # Implementation needed for `Pow.Extension.Base.has?/2` check
  defmodule ExtensionMock do
    use Pow.Extension.Base

    @impl true
    def ecto_schema?(), do: true

    @impl true
    def use_ecto_schema?(), do: true
  end

  defmodule ExtensionMock.Ecto.Schema do
    use Pow.Extension.Ecto.Schema.Base
    alias Ecto.Changeset

    @impl true
    def validate!(_config, module) do
      case module.pow_user_id_field() do
        :email -> :ok
        _      -> raise "User ID field error"
      end
    end

    @impl true
    def attrs(_config) do
      [{:custom, :string}]
    end

    @impl true
    def assocs(_config) do
      [
        {:belongs_to, :parent, :users},
        {:has_many, :children, :users, foreign_key: :parent_id}
      ]
    end

    @impl true
    def changeset(changeset, attrs, _config) do
      changeset = Changeset.cast(changeset, attrs, [:custom])

      case Changeset.get_field(changeset, :custom) do
        "error" -> Changeset.add_error(changeset, :custom, "custom error")
        _       -> changeset
      end
    end

    @impl true
    defmacro __using__(_config) do
      quote do
        def custom_function, do: true
      end
    end
  end

  defmodule User do
    use Ecto.Schema
    use Pow.Ecto.Schema
    use Pow.Extension.Ecto.Schema,
      extensions: [Pow.Extension.Ecto.SchemaTest.ExtensionMock]

    @ecto_derive_inspect_for_redacted_fields false

    schema "users" do
      pow_user_fields()

      timestamps()
    end

    def changeset(user, attrs) do
      user
      |> pow_changeset(attrs)
      |> pow_extension_changeset(attrs)
    end
  end

  module_raised_with =
    try do
      defmodule InvalidUser do
        use Ecto.Schema
        use Pow.Ecto.Schema,
          user_id_field: :username
        use Pow.Extension.Ecto.Schema,
          extensions: [Pow.Extension.Ecto.SchemaTest.ExtensionMock]

        @ecto_derive_inspect_for_redacted_fields false

        schema "users" do
          pow_user_fields()

          timestamps()
        end
      end
    rescue
      e in RuntimeError -> e.message
    end

  use Pow.Test.Ecto.TestCase
  doctest Pow.Extension.Ecto.Schema

  alias Pow.Extension.Ecto.Schema

  test "has defined fields" do
    user = %User{}
    assert Map.has_key?(user, :custom)
    assert Map.has_key?(user, :parent)
    assert Map.has_key?(user, :children)

    assert %Ecto.Association.BelongsTo{queryable: User} = User.__schema__(:association, :parent)
    assert %Ecto.Association.Has{cardinality: :many, queryable: User, related_key: :parent_id} = User.__schema__(:association, :children)
  end

  @password "secret1234"
  @valid_params %{
    "email" => "john.doe@example.com",
    "password" => @password,
    "password_confirmation" => @password,
    "custom" => "valid"
  }

  test "has changeset validation" do
    changeset = User.changeset(%User{}, @valid_params)
    assert changeset.valid?

    changeset = User.changeset(%User{}, Map.put(@valid_params, "custom", "error"))
    refute changeset.valid?
    assert changeset.errors[:custom] == {"custom error", []}
  end

  test "has custom function definitions" do
    assert Kernel.function_exported?(User, :custom_function, 0)
    assert User.custom_function()
  end

  test "validates attributes" do
    assert unquote(module_raised_with) == "User ID field error"
  end

  test "require_schema_field!/3" do
    assert_raise Schema.SchemaError, "A `:missing_field` schema field should be defined in #{inspect User} to use CustomExtension", fn ->
      Schema.require_schema_field!(User, :missing_field, CustomExtension)
    end
  end
end
