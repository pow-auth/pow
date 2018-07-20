defmodule Mix.Tasks.Pow.Ecto.MigrationUtils do
  alias Mix.{Ecto, Generator}

  @spec create_migration_files(atom(), binary(), binary()) :: any()
  def create_migration_files(repo, name, content) do
    base_name    = "#{Macro.underscore(name)}.exs"
    timestamp    = timestamp()

    repo
    |> Ecto.source_repo_priv()
    |> Path.join("migrations")
    |> maybe_create_directory()
    |> ensure_unique(base_name, name)
    |> Path.join("#{timestamp}_#{base_name}")
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
