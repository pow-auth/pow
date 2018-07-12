defmodule Mix.Tasks.Authex.Ecto.Gen.MigrationTest do
  use Authex.Test.Mix.TestCase

  alias Mix.Tasks.Authex.Ecto.Gen.Migration

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "tmp/#{inspect(Migration)}", otp_app: :authex]
  end

  @tmp_path Path.join(["tmp", inspect(Migration)])
  @options  ["-r", inspect(Repo)]


  setup do
    File.rm_rf!(@tmp_path)
    File.mkdir_p!(@tmp_path)

    :ok
  end

  test "generates migration" do
    File.cd! @tmp_path, fn ->
      Migration.run(@options)
      migrations_path = Path.join([@tmp_path, "migrations"])

      assert [migration_file] = File.ls!(migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_create_user\.exs$/)

      file = migrations_path |> Path.join(migration_file) |> File.read!()
      assert file =~ "defmodule #{inspect(Repo)}.Migrations.CreateUsers do"
    end
  end

  test "doesn't make duplicate migrations" do
    File.cd! @tmp_path, fn ->
      Migration.run(@options)
      assert_raise Mix.Error, "migration can't be created, there is already a migration file with name CreateUser.", fn ->
        Migration.run(@options)
      end
    end
  end
end
