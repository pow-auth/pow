defmodule Mix.Tasks.Pow.Extension.Ecto.Gen.MigrationsTest do
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
      [{:custom_string, :string, []}]
    end

    @impl true
    def assocs(_config) do
      [{:belongs_to, :user, :users}]
    end

    @impl true
    def indexes(_config) do
      [{:custom_string, true}]
    end
  end

  alias Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations

  defmodule Repo do
    def __adapter__, do: true
    def config, do: [priv: "./", otp_app: :pow]
  end

  use Pow.Test.Mix.TestCase

  @extension       ExtensionMock
  @extension_name  "MixTasksPowExtensionEctoGenMigrationsTestExtensionMock"
  @migrations_path "migrations"
  @options         ["-r", inspect(Repo), "--extension", @extension]

  test "generates migrations", context do
    File.cd!(context.tmp_path, fn ->
      Migrations.run(@options)

      assert [migration_file] = File.ls!(@migrations_path)
      assert String.match?(migration_file, ~r/^\d{14}_add_#{Macro.underscore(@extension_name)}_to_users\.exs$/)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "defmodule #{inspect(Repo)}.Migrations.Add#{@extension_name}ToUsers do"
      assert file =~ "alter table(:users)"
      assert file =~ "add :custom_string, :string"
      assert file =~ "add :user_id, references(\"users\", on_delete: :nothing)"
      assert file =~ "create unique_index(:users, [:custom_string])"
    end)
  end

  test "warns if no extensions", context do
    File.cd!(context.tmp_path, fn ->
      Migrations.run(["-r", inspect(Repo)])

      assert_received {:mix_shell, :error, ["No extensions was provided as arguments, or found in `config :pow, :pow` configuration."]}
    end)
  end

  test "warns no migration file", context do
    File.cd!(context.tmp_path, fn ->
      Migrations.run(["-r", inspect(Repo), "--extension", "PowResetPassword"])

      assert_received {:mix_shell, :info, ["Notice: No migration file will be generated for PowResetPassword as this extension doesn't require any migrations."]}
    end)
  end

  test "generates with `:binary_id`", context do
    options = @options ++ ~w(--binary-id)

    File.cd!(context.tmp_path, fn ->
      Migrations.run(options)

      assert [migration_file] = File.ls!(@migrations_path)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "add :custom_string, :string"
      assert file =~ "add :user_id, references(\"users\", on_delete: :nothing, type: :binary_id)"
    end)
  end

  describe "with `:otp_app` configuration" do
    setup do
      Application.put_env(:pow, :pow, extensions: [@extension])
      on_exit(fn ->
        Application.delete_env(:pow, :pow)
      end)
    end

    test "generates migrations", context do
      File.cd!(context.tmp_path, fn ->
        Application.put_env(:pow, :pow, extensions: [@extension])
        Migrations.run(["-r", inspect(Repo)])

        assert [_migration_file] = File.ls!(@migrations_path)
      end)
    end
  end

  test "doesn't make duplicate migrations", context do
    options = @options ++ ["--extension", @extension]

    File.cd!(context.tmp_path, fn ->
      assert_raise Mix.Error, "migration can't be created, there is already a migration file with name Add#{@extension_name}ToUsers.", fn ->
        Migrations.run(options)
      end
    end)
  end

  test "generates with `:generators` config", context do
    Application.put_env(:pow, :generators, binary_id: true)
    on_exit(fn ->
      Application.delete_env(:pow, :generators)
    end)

    File.cd!(context.tmp_path, fn ->
      Migrations.run(@options)

      assert [migration_file] = File.ls!(@migrations_path)

      file = @migrations_path |> Path.join(migration_file) |> File.read!()

      assert file =~ "add :custom_string, :string"
      assert file =~ "add :user_id, references(\"users\", on_delete: :nothing, type: :binary_id)"
    end)
  end
end
