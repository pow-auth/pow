defmodule Mix.Tasks.Pow.Ecto.Gen.Migration do
  @shortdoc "Generates user migration file"

  @moduledoc """
  Generates a user migrations file.

      mix pow.ecto.gen.migration -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.{Ecto, Pow.Utils, Tasks.Pow.Ecto.MigrationUtils}
  alias Pow.Ecto.Schema.Migration

  @doc false
  def run(args) do
    Utils.no_umbrella!("pow.ecto.gen.migration")

    create_migrations_files(args)
  end

  defp create_migrations_files(args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.each(&create_migration_files/1)
  end

  defp create_migration_files(repo) do
    context_base    = Utils.context_base(Utils.context_app())
    name            = Migration.name("users")
    content         = Migration.gen(context_base, repo: repo)

    MigrationUtils.create_migration_files(repo, name, content)
  end
end
