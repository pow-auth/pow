defmodule Pow.Ecto.Schema.MigrationTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema.Migration

  alias Pow.Ecto.Schema.Migration

  test "name/1" do
    assert Migration.name("users") == "CreateUsers"
  end

  test "migration_file/1" do
    content = Migration.gen(Pow)

    assert content =~ "defmodule Pow.Repo.Migrations.CreateUsers do"
    assert content =~ "create table(:users)"
    assert content =~ "add :email, :string, null: false"
    assert content =~ "add :password_hash, :string"
    refute content =~ ":current_password"
    assert content =~ "create unique_index(:users, [:email])"

    content = Migration.gen(Pow, user_id_field: :username)
    assert content =~ "add :username, :string, null: false"
    assert content =~ "create unique_index(:users, [:username])"

    content = Migration.gen(Test)
    assert content =~ "defmodule Test.Repo.Migrations.CreateUsers do"

    content = Migration.gen(Pow, binary_id: true)
    assert content =~ "add :id, :binary_id, primary_key: true"

    content = Migration.gen(Pow, table: "organizations")
    assert content =~ "defmodule Pow.Repo.Migrations.CreateOrganizations do"
    assert content =~ "create table(:organizations) do"
    assert content =~ "create unique_index(:organizations, [:email])"

    content = Migration.gen(Pow, attrs: [{:organization_id, {:references, "organizations"}}])
    assert content =~ "add :organization_id, references(\"organizations\"), on_delete: :nothing"

    content = Migration.gen(Pow, attrs: [{:organization_id, {:references, "organizations"}}], binary_id: true)
    assert content =~ "add :organization_id, references(\"organizations\"), on_delete: :nothing, type: :binary_id"

    content = Migration.gen(Pow, indexes: [{:key, true}])
    assert content =~ "create unique_index(:users, [:key])"

    content = Migration.gen(Pow, indexes: [{[:one, :two], true}])
    assert content =~ "create unique_index(:users, [:one, :two])"
  end
end
