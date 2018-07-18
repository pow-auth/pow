defmodule Mix.Tasks.Authex.Ecto.Gen.Migration do
  @shortdoc "Generates user migration file"

  @moduledoc """
  Generates a user migrations file.

      mix authex.ecto.gen.migration -r MyApp.Repo
  """
  use Mix.Task

  alias Authex.Ecto.Schema.Migration
  alias Mix.{Tasks.Authex.Ecto.MigrationUtils, Authex.Utils, Ecto}

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.ecto.gen.migration")

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
