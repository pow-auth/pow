defmodule Mix.Tasks.Pow.Ecto.Gen.MigrationTest do
  use Pow.Test.Mix.TestCase

  alias Mix.Tasks.Pow.Ecto.Gen.Migration

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "./", otp_app: :pow]
  end

  @options ["-r", inspect(Repo)]
  @migrations_path "migrations"

  test "generates migration", context do
    File.cd!(context.tmp_path, fn ->
      Migration.run(@options)

      assert_received {:mix_shell, :info, ["* creating ./migrations"]}
      assert_received {:mix_shell, :info, ["* creating ./migrations/" <> _]}

      assert [migration_file] = File.ls!(@migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_create_users\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()
      assert file =~ "defmodule #{inspect(Repo)}.Migrations.CreateUsers do"
      assert file =~ "create table(:users)"
    end)
  end

  test "doesn't make duplicate migrations", context do
    File.cd!(context.tmp_path, fn ->
      Migration.run(@options)

      assert_raise Mix.Error, "migration can't be created, there is already a migration file with name CreateUsers.", fn ->
        Migration.run(@options)
      end
    end)
  end

  test "generates with `:binary_id`", context do
    options = @options ++ ~w(--binary-id)
    File.cd!(context.tmp_path, fn ->
      Migration.run(options)

      assert [migration_file] = File.ls!(@migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_create_users\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "create table(:users, primary_key: false)"
      assert file =~ "add :id, :binary_id, primary_key: true"
    end)
  end

  test "generates with `:generators` config", context do
    Application.put_env(:pow, :generators, binary_id: true)
    on_exit(fn ->
      Application.delete_env(:pow, :generators)
    end)

    File.cd!(context.tmp_path, fn ->
      Migration.run(@options)

      assert [migration_file] = File.ls!(@migrations_path)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "create table(:users, primary_key: false)"
      assert file =~ "add :id, :binary_id, primary_key: true"
    end)
  end
end
