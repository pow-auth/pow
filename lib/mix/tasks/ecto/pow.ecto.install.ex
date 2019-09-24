defmodule Mix.Tasks.Pow.Ecto.Install do
  @shortdoc "Generates user schema module and migration file(s)"

  @moduledoc """
  Generates a user schema module and migration file(s).

      mix pow.ecto.install -r MyApp.Repo

      mix pow.ecto.install -r MyApp.Repo Accounts.Account accounts

  See `Mix.Tasks.Pow.Ecto.Gen.Schema`, `Mix.Tasks.Pow.Ecto.Gen.Migration`
  and `Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations` for more.

  ## Arguments

    * `--no-migrations` - don't generate migration files
    * `--no-schema` - don't generate schema file
    * `--extension` - extensions to generate migrations for
  """
  use Mix.Task

  alias Mix.Pow
  alias Mix.Tasks.Pow.Ecto.Gen.Migration, as: MigrationTask
  alias Mix.Tasks.Pow.Ecto.Gen.Schema, as: SchemaTask
  alias Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations, as: ExtensionMigrationsTask

  @switches [migrations: :boolean, schema: :boolean, extension: :keep]
  @default_opts [migrations: true, schema: true]
  @mix_task "pow.ecto.install"

  @impl true
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

  defp parse({config, parsed, _invalid}) do
    Pow.validate_schema_args!(parsed, @mix_task)

    config
  end

  defp maybe_run_gen_migration(%{migrations: true} = config, args) do
    MigrationTask.run(args)

    config
  end
  defp maybe_run_gen_migration(config, _args), do: config

  defp maybe_run_extension_gen_migrations(%{migrations: true, extension: extensions} = config, args) when extensions != [] do
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
