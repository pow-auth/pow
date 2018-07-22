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
  end
end
