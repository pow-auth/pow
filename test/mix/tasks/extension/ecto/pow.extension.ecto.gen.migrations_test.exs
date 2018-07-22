defmodule Mix.Tasks.Pow.Extension.Ecto.Gen.MigrationsTest do
  defmodule Ecto.Schema do
    use Pow.Extension.Ecto.Schema.Base

    def attrs(config) do
      [{:custom_string, :string, null: config[:binary_id] == true}]
    end

    def indexes(_config) do
      [{:custom_string, true}]
    end
  end

  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "tmp/#{inspect(Migrations)}", otp_app: :pow]
  end

  @tmp_path Path.join(["tmp", inspect(Migrations)])
  @migrations_path Path.join([@tmp_path, "migrations"])
  @options  ["-r", inspect(Repo), "--extension", __MODULE__]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates migrations" do
    File.cd! @tmp_path, fn ->
      Migrations.run(@options)
      assert [migration_file] = File.ls!(@migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_add_migrations_test_to_users\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()
      assert file =~ "defmodule #{inspect(Repo)}.Migrations.AddMigrationsTestToUsers do"
      assert file =~ "alter table(:users)"
      assert file =~ "add :custom_string, :string, null: false"
      assert file =~ "create unique_index(:users, [:custom_string])"
    end
  end

  test "generates with :binary_id" do
    File.cd! @tmp_path, fn ->
      Migrations.run(@options ++ ~w(--binary-id))
      assert [migration_file] = File.ls!(@migrations_path)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()
      assert file =~ "add :custom_string, :string, null: true"
    end
  end

  test "doesn't make duplicate migrations" do
    File.cd! @tmp_path, fn ->
      assert_raise Mix.Error, "migration can't be created, there is already a migration file with name AddMigrationsTestToUsers.", fn ->
        Migrations.run(@options ++ ["--extension", __MODULE__])
      end
    end
  end
end
