defmodule Mix.Tasks.Pow.Ecto.Install do
  @shortdoc "Generates user schema module and migrations file"

  @moduledoc """
  Generates a user schema module and migrations file.

      mix pow.ecto.install -r MyApp.Repo

      mix pow.ecto.install -r MyApp.Repo Accounts.Organization organizations

  This generator will add the following files to `lib/`:

    * a schema in `lib/my_app/users/user.ex` for `users` table
    * a migration file in `priv/repo/migrations` for `users` table

  ## Arguments

    * `--no-migrations` don't generate migration files
    * `--no-schema` don't generate schema file
    * `--extension` extension to generate migrations for
  """
  use Mix.Task

  alias Mix.Tasks.Pow.Ecto.Gen.Schema, as: SchemaTask
  alias Mix.Tasks.Pow.Ecto.Gen.Migration, as: MigrationTask
  alias Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations, as: ExtensionMigrationsTask
  alias Mix.Pow

  @switches [migrations: :boolean, schema: :boolean, extension: :keep]
  @default_opts [migrations: true, schema: true]
  @mix_task "pow.ecto.install"

  @doc false
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_ecto!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> maybe_run_gen_migration(args)
    |> maybe_run_extension_gen_migrations(args)
    |> maybe_run_gen_schema(args)
  end

  defp parse({config, _parsed, _invalid}), do: config

  defp maybe_run_gen_migration(%{migrations: true} = config, args) do
    MigrationTask.run(args)

    config
  end
  defp maybe_run_gen_migration(config, _args), do: config

  defp maybe_run_extension_gen_migrations(%{migrations: true} = config, args) do
    ExtensionMigrationsTask.run(args)

    config
  end
  defp maybe_run_extension_gen_migrations(config, _args), do: config

  defp maybe_run_gen_schema(%{schema: true} = config, args) do
    SchemaTask.run(args ++ ~w(--no-migrations))

    config
  end
  defp maybe_run_gen_schema(config, _args), do: config
end
