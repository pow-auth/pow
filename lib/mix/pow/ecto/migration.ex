defmodule Mix.Pow.Ecto.Migration do
  @moduledoc """
  Utilities module for ecto migrations in mix tasks.
  """
  alias Mix.Generator

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `create_migration_file/3`"
  defdelegate create_migration_files(repo, name, content), to: __MODULE__, as: :create_migration_file

  @doc """
  Creates a migration file for a repo.
  """
  @spec create_migration_file(atom(), binary(), binary()) :: any()
  def create_migration_file(repo, name, content) do
    base_name = "#{Macro.underscore(name)}.exs"
    path      =
      repo
      |> source_repo_priv()
      |> Path.join("migrations")
      |> maybe_create_directory()
    timestamp = timestamp(path)

    path
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

  defp timestamp(path, seconds \\ 0) do
    timestamp = gen_timestamp(seconds)

    path
    |> Path.join("#{timestamp}_*.exs")
    |> Path.wildcard()
    |> case do
      [] -> timestamp
      _  -> timestamp(path, seconds + 1)
    end
  end

  defp gen_timestamp(seconds) do
    %{year: y, month: m, day: d, hour: hh, minute: mm, second: ss} =
      DateTime.utc_now()
      |> DateTime.to_unix()
      |> Kernel.+(seconds)
      |> DateTime.from_unix!()

    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  # TODO: Remove by 1.1.0 and only use Ecto 3.0
  defp source_repo_priv(repo) do
    mod =
      if Pow.dependency_vsn_match?(:ecto, "< 3.0.0"),
        do: Mix.Ecto,
        else: Mix.EctoSQL

    mod.source_repo_priv(repo)
  end
end
