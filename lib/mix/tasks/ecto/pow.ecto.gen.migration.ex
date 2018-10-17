defmodule Mix.Tasks.Pow.Ecto.Gen.Migration do
  @shortdoc "Generates user migration file"

  @moduledoc """
  Generates a user migrations file.

      mix pow.ecto.gen.migration -r MyApp.Repo

      mix pow.ecto.gen.migration -r MyApp.Repo Accounts.Organization organizations
  """
  use Mix.Task

  alias Pow.Ecto.Schema.Migration, as: SchemaMigration
  alias Mix.{Ecto, Pow, Pow.Ecto.Migration}

  @switches [binary_id: :boolean]
  @default_opts [binary_id: false]
  @mix_task "pow.ecto.install"

  @doc false
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_ecto!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> create_migrations_files(args)
  end

  defp parse({config, parsed, _invalid}) do
    case parsed do
      [_schema_name, schema_plural | _rest] ->
        Map.merge(config, %{schema_plural: schema_plural})

      _ ->
        config
    end
  end

  defp create_migrations_files(config, args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_migration_files/1)
  end

  defp create_migration_files(%{repo: repo, binary_id: binary_id} = config) do
    context_base  = Pow.context_base(Pow.context_app())
    schema_plural = Map.get(config, :schema_plural, "users")
    schema        = SchemaMigration.new(context_base, schema_plural, repo: repo, binary_id: binary_id)
    content       = SchemaMigration.gen(schema)

    Migration.create_migration_files(repo, schema.migration_name, content)
  end
end
