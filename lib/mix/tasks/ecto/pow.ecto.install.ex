defmodule Mix.Tasks.Pow.Ecto.Install do
  @shortdoc "Generates user schema module and migrations file"

  @moduledoc """
  Generates a user schema module and migrations file.

      mix pow.ecto.install -r MyApp.Repo

  This generator will add the following files to `lib/`:
  * a schema in lib/my_app/users/user.ex for `users` table
  * a migration file in priv/repo/migrations for `users` table
  """
  use Mix.Task

  alias Mix.Pow.Utils
  alias Mix.Tasks.Pow.{Ecto.Gen, Extension}

  @switches [migrations: :boolean, schema: :boolean, extension: :keep]
  @default_opts [migrations: true, schema: true]

  @doc false
  def run(args) do
    Utils.no_umbrella!("pow.ecto.install")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> maybe_run_gen_migration(args)
    |> maybe_run_extension_gen_migrations(args)
    |> maybe_run_gen_schema(args)
  end

  defp maybe_run_gen_migration(%{migrations: true} = config, args) do
    Gen.Migration.run(args)

    config
  end
  defp maybe_run_gen_migration(config, _args), do: config

  defp maybe_run_extension_gen_migrations(%{migrations: true} = config, args) do
    Extension.Ecto.Gen.Migrations.run(args)

    config
  end
  defp maybe_run_extension_gen_migrations(config, _args), do: config

  defp maybe_run_gen_schema(%{schema: true} = config, args) do
    Gen.Schema.run(args ++ ~w(--no-migrations))

    config
  end
  defp maybe_run_gen_schema(config, _args), do: config
end
