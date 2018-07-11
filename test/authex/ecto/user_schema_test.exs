defmodule Authex.Ecto.UserSchemaTest do
  use ExUnit.Case
  doctest Authex.Ecto.UserSchema

  alias Authex.Ecto.UserSchema
  alias Authex.Test.Ecto.Users.User

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :email)
    assert Map.has_key?(user, :current_password)
  end

  test "migration_file/1" do
    content = UserSchema.migration_file(Authex)

    assert content =~ "defmodule Authex.Repo.Migrations.CreateUsers do"
    assert content =~ "create table(:users)"
    assert content =~ "add :email, :string, null: false"
    assert content =~ "add :password_hash, :string"
    refute content =~ ":current_password"
    assert content =~ "create unique_index(:users, [:email])"

    content = UserSchema.migration_file(Authex, login_field: :username)
    assert content =~ "add :username, :string, null: false"
    assert content =~ "create unique_index(:users, [:username])"

    content = UserSchema.migration_file(Test)
    assert content =~ "defmodule Test.Repo.Migrations.CreateUsers do"
  end

  test "schema_file/1" do
    content = UserSchema.schema_file(Authex)

    assert content =~ "defmodule Authex.Users.User do"
    assert content =~ "schema \"users\" do"
    assert content =~ "Authex.Ecto.UserSchema.user_schema()"

    content = UserSchema.schema_file(Authex, login_field: :username)
    assert content =~ "Authex.Ecto.UserSchema.user_schema(login_field: :username)"

    content = UserSchema.schema_file(Test)
    assert content =~ "defmodule Test.Users.User do"
  end
end
