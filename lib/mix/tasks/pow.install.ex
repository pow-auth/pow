defmodule Mix.Tasks.Pow.Install do
  @shortdoc "Installs Pow"

  @moduledoc """
  Will generate pow module files, a user schema module, migrations file.

      mix pow.install -r MyApp.Repo

  ## Arguments

    * `--templates` generate templates and views
    * `--no-migrations` don't generate migration files
    * `--no-schema` don't generate schema file
    * `--extension` extension to generate templates and views for
  """
  use Mix.Task

  alias Mix.{Pow, Project}
  alias Mix.Tasks.Pow.{Ecto, Phoenix}

  @switches [context_app: :string, extension: :keep]
  @default_opts []

  @doc false
  def run(args) do
    no_umbrella!()

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> run_ecto_install(args)
    |> run_phoenix_install(args)
  end

  defp parse({config, _parsed, _invalid}), do: config

  defp run_ecto_install(config, args) do
    Ecto.Install.run(args)

    config
  end

  defp run_phoenix_install(config, args) do
    Phoenix.Install.run(args)

    config
  end

  defp no_umbrella! do
    if Project.umbrella?() do
      Mix.raise("mix pow.install can't be used in umbrella apps. Run mix pow.ecto.install in your ecto app directory, and optionally mix pow.phoenix.install in your phoenix app directory.")
    end

    :ok
  end
end
