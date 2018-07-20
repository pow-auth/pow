defmodule Mix.Tasks.Pow.Ecto.Gen.MigrationTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Gen.Migration

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "tmp/#{inspect(Migration)}", otp_app: :pow]
  end

  @tmp_path Path.join(["tmp", inspect(Migration)])
  @migrations_path Path.join([@tmp_path, "migrations"])
  @options  ["-r", inspect(Repo)]

  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates migration" do
    File.cd! @tmp_path, fn ->
      Migration.run(@options)

      assert [migration_file] = File.ls!(@migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_create_users\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()
      assert file =~ "defmodule #{inspect(Repo)}.Migrations.CreateUsers do"
      assert file =~ "create table(:users)"
    end
  end

  test "doesn't make duplicate migrations" do
    File.cd! @tmp_path, fn ->
      Migration.run(@options)
      assert_raise Mix.Error, "migration can't be created, there is already a migration file with name CreateUsers.", fn ->
        Migration.run(@options)
      end
    end
  end

  test "generates with binary_id" do
    File.cd! @tmp_path, fn ->
      Migration.run(@options ++ ~w(--binary-id))
      assert [migration_file] = File.ls!(@migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_create_users\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()
      assert file =~ "create table(:users, primary_key: false)"
      assert file =~ "add :id, :binary_id, primary_key: true"
    end
  end
end
