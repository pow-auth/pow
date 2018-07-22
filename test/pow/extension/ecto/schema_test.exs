defmodule Pow.Test.Extension.Ecto.Schema.Ecto.Schema do
  use Pow.Extension.Ecto.Schema.Base
  alias Ecto.Changeset

  def validate!(_config, module) do
    case module.pow_user_id_field() do
      :email -> :ok
      _      -> raise "User ID field error"
    end
  end

  def attrs(_config) do
    [{:custom, :string}]
  end

  def changeset(changeset, attrs, _config) do
    changeset = Changeset.cast(changeset, attrs, [:custom])

    case Changeset.get_field(changeset, :custom) do
      "error" -> Changeset.add_error(changeset, :custom, "custom error")
      _       -> changeset
    end
  end
end

defmodule Pow.Test.Extension.Ecto.Schema.User do
  use Ecto.Schema
  use Pow.Ecto.Schema
  use Pow.Extension.Ecto.Schema,
    extensions: [Pow.Test.Extension.Ecto.Schema]

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

module_raised_with = try do
  defmodule Pow.Test.Extension.Ecto.Schema.InvalidUser do
    use Ecto.Schema
    use Pow.Ecto.Schema,
    user_id_field: :username
    use Pow.Extension.Ecto.Schema,
      extensions: [Pow.Test.Extension.Ecto.Schema]

    schema "users" do
      pow_user_fields()

      timestamps()
    end
  end
rescue
  e in RuntimeError -> e.message
end

defmodule Pow.Extension.Ecto.SchemaTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Extension.Ecto.Schema

  alias Pow.Extension.Ecto.Schema
  alias Pow.Test.Extension.Ecto.Schema.User

  test "has defined fields" do
    user = %User{}
    assert Map.has_key?(user, :custom)
  end

  @password "secret1234"
  @valid_params %{
    "email" => "john.doe@example.com",
    "password" => @password,
    "confirm_password" => @password,
    "custom" => "valid"
  }

  test "has changeset validation" do
    changeset = User.changeset(%User{}, @valid_params)
    assert changeset.valid?

    changeset = User.changeset(%User{}, Map.put(@valid_params, "custom", "error"))
    refute changeset.valid?
    assert changeset.errors[:custom] == {"custom error", []}
  end

  test "validates attributes" do
    assert unquote(module_raised_with) == "User ID field error"
  end

  test "require_schema_field!/3" do
    assert_raise Schema.SchemaError, "A `:missing_field` schema field should be defined in Pow.Test.Extension.Ecto.Schema.User to use CustomExtension", fn ->
      Schema.require_schema_field!(User, :missing_field, CustomExtension)
    end
  end
end
