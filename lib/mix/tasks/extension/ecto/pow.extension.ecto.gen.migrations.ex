defmodule Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations do
  @shortdoc "Generates user extension migration files"

  @moduledoc """
  Generates a migration files for extensions.

      mix pow.extension.ecto.gen.migrations -r MyApp.Repo
  """
  use Mix.Task

  alias Pow.Extension.Ecto.Schema.Migration
  alias Mix.{Ecto, Pow.Extension, Pow.Utils, Tasks.Pow.Ecto.MigrationUtils}

  @switches [extension: :keep]
  @default_opts []

  @doc false
  def run(args) do
    Utils.no_umbrella!("pow.extension.ecto.gen.migrations")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> create_migrations_files(args)
  end

  defp create_migrations_files(config, args) do
    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.each(&create_extension_migration_files(&1, Extension.Utils.extensions(config)))
  end

  defp create_extension_migration_files(repo, extensions) do
    context_base = Utils.context_base(Utils.context_app())
    for extension <- extensions,
      do: create_migration_files(repo, extension, context_base)
  end

  defp create_migration_files(repo, extension, context_base) do
    name    = Migration.name(extension, "users")
    content = Migration.gen(extension, context_base, repo: repo)

    MigrationUtils.create_migration_files(repo, name, content)
  end
end
