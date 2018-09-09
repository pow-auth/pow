defmodule Pow.Ecto.SchemaTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema

  alias Pow.Test.Ecto.Users.{User, UsernameUser}

  test "schema/2" do
    user = %User{}

    assert Map.has_key?(user, :email)
    assert Map.has_key?(user, :current_password)
    refute Map.has_key?(user, :username)

    user = %UsernameUser{}
    assert Map.has_key?(user, :username)
    refute Map.has_key?(user, :email)
  end

  test "changeset/2" do
    changeset = User.changeset(%User{}, %{custom: "custom"})
    assert changeset.changes.custom == "custom"
  end

  defmodule OverrideFieldUser do
    @moduledoc false
    use Ecto.Schema
    use Pow.Ecto.Schema

    schema "users" do
      field :password_hash, :string, source: :encrypted_password

      pow_user_fields()

      timestamps()
    end
  end

  test "schema/2 with overriden fields" do
    user = %OverrideFieldUser{}

    assert Map.has_key?(user, :password_hash)
    assert OverrideFieldUser.__schema__(:field_source, :password_hash) == :encrypted_password
  end
end
