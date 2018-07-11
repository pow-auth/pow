defmodule Mix.Tasks.Authex.Ecto.Install do
  @shortdoc "Generates user schema module and migrations file"

  @moduledoc """
  Generates a user schema module and migrations file.

      mix authex.ecto.install -r MyApp.Repo

  This generator will add the following files to `lib/`:
  * a schema in lib/my_app/users/user.ex for `users` table
  * a migration file in priv/repo/migrations for `users` table
  """
  use Mix.Task

  alias Mix.Tasks.Authex.Ecto.Gen
  alias Mix.Ecto

  @switches [migrations: :boolean, schema: :boolean]
  @default_opts [migrations: true, schema: true]

  @doc false
  def run(args) do
    Ecto.no_umbrella!("authex.ecto.install")

    args
    |> parse_options()
    |> maybe_run_gen_migration(args)
    |> maybe_run_gen_schema(args)
  end

  defp parse_options(args) do
    {opts, _parsed, _invalid} = OptionParser.parse(args, switches: @switches)

    @default_opts
    |> Keyword.merge(opts)
    |> Map.new()
  end

  defp maybe_run_gen_migration(%{migrations: true} = config, args) do
    Gen.Migration.run(args)

    config
  end
  defp maybe_run_gen_migration(config, _args), do: config

  defp maybe_run_gen_schema(%{schema: true} = config, args) do
    Gen.Schema.run(args ++ ~w(--no-migrations))

    config
  end
  defp maybe_run_gen_schema(config, _args), do: config
end
