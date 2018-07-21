defmodule Mix.Tasks.Pow.Ecto.Gen.Migration do
  @shortdoc "Generates user migration file"

  @moduledoc """
  Generates a user migrations file.

      mix pow.ecto.gen.migration -r MyApp.Repo
  """
  use Mix.Task

  alias Pow.Ecto.Schema.Migration, as: SchemaMigration
  alias Mix.{Ecto, Pow, Pow.Ecto.Migration}

  @switches [binary_id: :boolean]
  @default_opts [binary_id: false]

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow.ecto.gen.migration")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_migrations_files(args)
  end

  defp create_migrations_files(config, args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_migration_files/1)
  end

  defp create_migration_files(%{repo: repo, binary_id: binary_id}) do
    context_base    = Pow.context_base(Pow.context_app())
    name            = SchemaMigration.name("users")
    content         = SchemaMigration.gen(context_base, repo: repo, binary_id: binary_id)

    Migration.create_migration_files(repo, name, content)
  end
end
