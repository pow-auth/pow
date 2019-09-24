defmodule Mix.Tasks.Pow.Ecto.Gen.Migration do
  @shortdoc "Generates user migration file"

  @moduledoc """
  Generates a user migration file.

      mix pow.ecto.gen.migration -r MyApp.Repo

      mix pow.ecto.gen.migration -r MyApp.Repo Accounts.Account accounts

  This generator will add a migration file in `priv/repo/migrations` for the
  `users` table

  ## Arguments

    * `-r`, `--repo` - the repo module
    * `--binary-id` - use binary id for primary key
  """
  use Mix.Task

  alias Pow.Ecto.Schema.Migration, as: SchemaMigration
  alias Mix.{Ecto, Pow, Pow.Ecto.Migration}

  @switches [binary_id: :boolean]
  @default_opts [binary_id: false]
  @mix_task "pow.ecto.gen.migration"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_ecto!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> create_migration_files(args)
  end

  defp parse({config, parsed, _invalid}) do
    parsed
    |> Pow.validate_schema_args!(@mix_task)
    |> Map.merge(config)
  end

  defp create_migration_files(config, args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_migration_files/1)
  end

  defp create_migration_files(%{repo: repo, binary_id: binary_id, schema_plural: schema_plural}) do
    context_base = Pow.app_base(Pow.otp_app())
    schema       = SchemaMigration.new(context_base, schema_plural, repo: repo, binary_id: binary_id)
    content      = SchemaMigration.gen(schema)

    Migration.create_migration_file(repo, schema.migration_name, content)
  end
end
