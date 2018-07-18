defmodule Authex.Ecto.Schema.MigrationTest do
  use ExUnit.Case
  doctest Authex.Ecto.Schema.Migration

  alias Authex.Ecto.Schema.Migration

  test "name/1" do
    assert Migration.name("users") == "CreateUsers"
  end

  test "migration_file/1" do
    content = Migration.gen(Authex)

    assert content =~ "defmodule Authex.Repo.Migrations.CreateUsers do"
    assert content =~ "create table(:users)"
    assert content =~ "add :email, :string, null: false"
    assert content =~ "add :password_hash, :string"
    refute content =~ ":current_password"
    assert content =~ "create unique_index(:users, [:email])"

    content = Migration.gen(Authex, login_field: :username)
    assert content =~ "add :username, :string, null: false"
    assert content =~ "create unique_index(:users, [:username])"

    content = Migration.gen(Test)
    assert content =~ "defmodule Test.Repo.Migrations.CreateUsers do"
  end
end
