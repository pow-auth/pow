defmodule Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations do
  @shortdoc "Generates user extension migration files"

  @moduledoc """
  Generates a migration files for extensions.

      mix pow.extension.ecto.gen.migrations -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.{Ecto, Pow.Extension, Pow.Utils, Tasks.Pow.Ecto.MigrationUtils}
  alias Pow.Extension.Ecto.Schema.Migration

  @switches [binary_id: :boolean, extension: :keep]
  @default_opts [binary_id: false]

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
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_extension_migration_files/1)
  end

  defp create_extension_migration_files(config) do
    extensions   = Extension.Utils.extensions(config)
    context_base = Utils.context_base(Utils.context_app())

    for extension <- extensions,
      do: create_migration_files(config, extension, context_base)
  end

  defp create_migration_files(%{repo: repo, binary_id: binary_id}, extension, context_base) do
    name    = Migration.name(extension, "users")
    content = Migration.gen(extension, context_base, repo: repo, binary_id: binary_id)

    MigrationUtils.create_migration_files(repo, name, content)
  end
end
