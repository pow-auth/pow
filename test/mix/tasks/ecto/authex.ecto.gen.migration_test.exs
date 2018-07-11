defmodule Mix.Tasks.Authex.Ecto.Gen.MigrationTest do
  use ExUnit.Case

  alias Mix.Tasks.Authex.Ecto.Gen.Migration

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "tmp/#{inspect(Migration)}", otp_app: :authex]
  end

  @migrations_path "tmp/#{inspect(Migration)}/migrations"
  @options         ["-r", inspect(Repo)]

  setup do
    File.rm_rf!(@migrations_path)

    :ok
  end

  test "generates migration" do
    Migration.run(@options)

    assert [migration_file] = File.ls!(@migrations_path)
    assert String.match?(migration_file, ~r/^\d{14}_create_user\.exs$/)

    file = @migrations_path |> Path.join(migration_file) |> File.read!()
    assert file =~ "defmodule #{inspect(Repo)}.Migrations.CreateUsers do"
  end

  test "doesn't make duplicate migrations" do
    Migration.run(@options)
    assert_raise Mix.Error, "migration can't be created, there is already a migration file with name CreateUser.", fn ->
      Migration.run(@options)
    end
  end
end
