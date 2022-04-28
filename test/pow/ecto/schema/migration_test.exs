defmodule Pow.Ecto.Schema.MigrationTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema.Migration

  alias Pow.Ecto.Schema.Migration

  test "new/2" do
    schema = Migration.new(Pow, "users")

    assert schema.migration_name == "CreateUsers"
    assert schema.repo == Pow.Repo
    refute schema.binary_id

    schema = Migration.new(Test, "organizations", binary_id: true)

    assert schema.migration_name == "CreateOrganizations"
    assert schema.repo == Test.Repo
    assert schema.binary_id

    assert_raise RuntimeError, "The attribute is required to have the format `{name, type, field_options, migration_options}`.\n\nThe attribute provided was: :invalid\n", fn ->
      Migration.new(Pow, "users", attrs: [:invalid])
    end
  end

  test "gen/1" do
    content = Migration.gen(Migration.new(Pow, "users"))

    assert content =~ "defmodule Pow.Repo.Migrations.CreateUsers do"
    assert content =~ "create table(:users)"
    assert content =~ "add :email, :string, null: false"
    assert content =~ "add :password_hash, :string"
    refute content =~ ":current_password"
    assert content =~ "create unique_index(:users, [:email])"

    content = Migration.gen(Migration.new(Pow, "users", user_id_field: :username))
    assert content =~ "add :username, :string, null: false"
    assert content =~ "create unique_index(:users, [:username])"

    content = Migration.gen(Migration.new(Test, "users"))
    assert content =~ "defmodule Test.Repo.Migrations.CreateUsers do"

    content = Migration.gen(Migration.new(Pow, "users", binary_id: true))
    assert content =~ "add :id, :binary_id, primary_key: true"

    content = Migration.gen(Migration.new(Pow, "organizations"))
    assert content =~ "defmodule Pow.Repo.Migrations.CreateOrganizations do"
    assert content =~ "create table(:organizations) do"
    assert content =~ "create unique_index(:organizations, [:email])"

    content = Migration.gen(Migration.new(Pow, "users", attrs: [{:organization_id, {:references, "organizations"}, [], []}]))
    assert content =~ "add :organization_id, references(\"organizations\", on_delete: :nothing)"

    content = Migration.gen(Migration.new(Pow, "users", attrs: [{:organization_id, {:references, "organizations"}, [], []}], binary_id: true))
    assert content =~ "add :organization_id, references(\"organizations\", on_delete: :nothing, type: :binary_id)"

    content = Migration.gen(Migration.new(Pow, "users", indexes: [{:key, true}]))
    assert content =~ "create unique_index(:users, [:key])"

    content = Migration.gen(Migration.new(Pow, "users", indexes: [{[:one, :two], true}]))
    assert content =~ "create unique_index(:users, [:one, :two])"
  end
end
