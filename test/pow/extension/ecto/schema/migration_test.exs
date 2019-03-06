defmodule Pow.Extension.Ecto.Schema.MigrationTest do
  defmodule Ecto.Schema do
    use Pow.Extension.Ecto.Schema.Base

    def attrs(_config) do
      [
        {:custom_string, :string, null: false},
        {:custom_at, :utc_datetime}
      ]
    end

    def assocs(_config) do
      [
        {:belongs_to, :parent, :users},
        {:has_many, :children, :users, foreign_key: :parent_id}
      ]
    end

    def indexes(_config) do
      [{:custom_string, true}]
    end
  end

  use ExUnit.Case
  doctest Pow.Extension.Ecto.Schema.Migration

  alias Pow.Extension.Ecto.Schema.Migration

  @extension "PowExtensionEctoSchemaMigrationTest"

  test "new/1" do
    schema = Migration.new(__MODULE__, Pow, "users", [])

    assert schema.migration_name == "Add#{@extension}ToUsers"
    assert schema.repo == Pow.Repo
    refute schema.binary_id

    schema = Migration.new(__MODULE__, Test, "organizations", binary_id: true)

    assert schema.migration_name == "Add#{@extension}ToOrganizations"
    assert schema.repo == Test.Repo
    assert schema.binary_id
  end

  test "gen/1" do
    content = Migration.gen(Migration.new(__MODULE__, Pow, "users"))

    assert content =~ "defmodule Pow.Repo.Migrations.Add#{@extension}ToUsers do"
    assert content =~ "alter table(:users)"
    assert content =~ "add :custom_string, :string, null: false"
    assert content =~ "add :custom_at, :utc_datetime"
    assert content =~ "add :parent_id, references(\"users\", on_delete: :nothing)"
    assert content =~ "create unique_index(:users, [:custom_string])"

    content = Migration.gen(Migration.new(__MODULE__, Test, "users"))
    assert content =~ "defmodule Test.Repo.Migrations.Add#{@extension}ToUsers do"
  end
end
