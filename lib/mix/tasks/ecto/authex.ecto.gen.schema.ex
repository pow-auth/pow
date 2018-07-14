defmodule Mix.Tasks.Authex.Ecto.Gen.Schema do
  @shortdoc "Generates user schema and migration file"

  @moduledoc """
  Generates a user schema and migration file.

      mix authex.ecto.gen.schema -r MyApp.Repo
  """
  use Mix.Task

  alias Authex.Ecto.Schema.Module
  alias Mix.Tasks.Authex.Ecto.Gen
  alias Mix.{Authex.Utils, Generator}

  @switches [migrations: :boolean, context_app: :string]
  @default_opts [migrations: true]

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.ecto.gen.schema")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> maybe_run_gen_migration(args)
    |> create_schema_file()
  end

  defp maybe_run_gen_migration(%{migrations: true} = config, args) do
    Gen.Migration.run(args)

    config
  end
  defp maybe_run_gen_migration(config, _args), do: config

  defp create_schema_file(config) do
    context_app  = Map.get(config, :context_app, Utils.context_app())
    context_base = Utils.context_base(context_app)

    base_name = "user.ex"
    content   = Module.gen(context_base, module: "Users.User")

    context_app
    |> Utils.context_lib_path("users")
    |> maybe_create_directory()
    |> Path.join(base_name)
    |> ensure_unique()
    |> Generator.create_file(content)
  end

  defp maybe_create_directory(path) do
    Generator.create_directory(path)

    path
  end

  defp ensure_unique(path) do
    path
    |> File.exists?()
    |> case do
      false -> path
      _     -> Mix.raise("schema file can't be created, there is already a schema file in #{path}.")
    end
  end
end
