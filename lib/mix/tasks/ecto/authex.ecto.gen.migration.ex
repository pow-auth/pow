defmodule Mix.Tasks.Authex.Ecto.Gen.Migration do
  @shortdoc "Generates user migration file"

  @moduledoc """
  Generates a user migrations file.

      mix authex.ecto.gen.migration -r MyApp.Repo
  """
  use Mix.Task

  alias Authex.Ecto.Schema.Migration
  alias Mix.{Authex.Utils, Ecto, Generator}

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
    path =
      repo
      |> Ecto.source_repo_priv()
      |> Path.join("migrations")
    name = "CreateUser"
    base_name = "#{Macro.underscore(name)}.exs"
    context_base = Utils.context_base(Utils.context_app())
    content = Migration.gen(context_base, repo: repo)

    path
    |> maybe_create_directory()
    |> ensure_unique(base_name, name)
    |> Path.join("#{timestamp()}_#{base_name}")
    |> Generator.create_file(content)
  end

  defp maybe_create_directory(path) do
    Generator.create_directory(path)

    path
  end

  defp ensure_unique(path, base_name, name) do
    path
    |> Path.join("*_#{base_name}")
    |> Path.wildcard()
    |> case do
      [] -> path
      _  -> Mix.raise("migration can't be created, there is already a migration file with name #{name}.")
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: << ?0, ?0 + i >>
  defp pad(i), do: to_string(i)
end
