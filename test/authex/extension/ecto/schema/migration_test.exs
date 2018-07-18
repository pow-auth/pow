defmodule AuthexTestExtension.Ecto.Schema do
  use Authex.Extension.Ecto.Schema.Base

  def attrs(_config) do
    [{:custom_string, :string, null: false},
     {:custom_at, :utc_datetime}]
  end

  def indexes(_config) do
    [{:custom_string, true}]
  end
end

defmodule Authex.Extension.Ecto.Schema.MigrationTest do
  use ExUnit.Case
  doctest Authex.Extension.Ecto.Schema.Migration

  alias Authex.Extension.Ecto.Schema.Migration

  test "name/1" do
    assert Migration.name(AuthexTestExtension, "users") == "AddAuthexTestExtensionToUsers"
  end

  test "migration_file/1" do
    content = Migration.gen(AuthexTestExtension, Authex)

    assert content =~ "defmodule Authex.Repo.Migrations.AddAuthexTestExtensionToUsers do"
    assert content =~ "alter table(:users)"
    assert content =~ "add :custom_string, :string, null: false"
    assert content =~ "add :custom_at, :utc_datetime"
    assert content =~ "create unique_index(:users, [:custom_string])"

    content = Migration.gen(AuthexTestExtension, Test)
    assert content =~ "defmodule Test.Repo.Migrations.AddAuthexTestExtensionToUsers do"
  end
end
