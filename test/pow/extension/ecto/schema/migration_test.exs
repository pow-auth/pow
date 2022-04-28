defmodule Pow.Extension.Ecto.Schema.MigrationTest do
  # Implementation needed for `Pow.Extension.Base.has?/2` check
  defmodule ExtensionMock do
    use Pow.Extension.Base

    @impl true
    def ecto_schema?(), do: true
  end

  defmodule ExtensionMock.Ecto.Schema do
    use Pow.Extension.Ecto.Schema.Base

    @impl true
    def attrs(_config) do
      [
        {:custom_string, :string, [default: "test"], [null: false]},
        {:custom_at, :utc_datetime}
      ]
    end

    @impl true
    def assocs(_config) do
      [
        {:belongs_to, :parent, :users},
        {:has_many, :children, :users, foreign_key: :parent_id}
      ]
    end

    @impl true
    def indexes(_config) do
      [{:custom_string, true}]
    end
  end

  use ExUnit.Case
  doctest Pow.Extension.Ecto.Schema.Migration

  alias Pow.Extension.Ecto.Schema.Migration

  @extension      ExtensionMock
  @extension_name "PowExtensionEctoSchemaMigrationTestExtensionMock"

  test "new/1" do
    schema = Migration.new(@extension, Pow, "users", [])

    assert schema.migration_name == "Add#{@extension_name}ToUsers"
    assert schema.repo == Pow.Repo
    refute schema.binary_id

    schema = Migration.new(@extension, Test, "organizations", binary_id: true)

    assert schema.migration_name == "Add#{@extension_name}ToOrganizations"
    assert schema.repo == Test.Repo
    assert schema.binary_id
  end

  test "gen/1" do
    content = Migration.gen(Migration.new(@extension, Pow, "users"))

    assert content =~ "defmodule Pow.Repo.Migrations.Add#{@extension_name}ToUsers do"
    assert content =~ "alter table(:users)"
    assert content =~ "add :custom_string, :string, default: \"test\", null: false"
    assert content =~ "add :custom_at, :utc_datetime"
    assert content =~ "add :parent_id, references(\"users\", on_delete: :nothing)"
    assert content =~ "create unique_index(:users, [:custom_string])"

    content = Migration.gen(Migration.new(@extension, Test, "users"))
    assert content =~ "defmodule Test.Repo.Migrations.Add#{@extension_name}ToUsers do"
  end
end
