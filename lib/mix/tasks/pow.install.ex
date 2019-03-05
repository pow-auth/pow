defmodule Mix.Tasks.Pow.Install do
  @shortdoc "Installs Pow"

  @moduledoc """
  Will generate pow module files, a user schema module, migrations file.

      mix pow.install -r MyApp.Repo

      mix pow.install -r MyApp.Repo Accounts.Organization organizations

  ## Arguments

    * `--templates` generate templates and views
    * `--no-migrations` don't generate migration files
    * `--no-schema` don't generate schema file
    * `--extension` extension to generate templates and views for
  """
  use Mix.Task

  alias Mix.Project
  alias Mix.{Pow, Tasks.Pow.Ecto, Tasks.Pow.Phoenix}

  @doc false
  def run(args) do
    no_umbrella!()

    args
    |> run_ecto_install()
    |> run_phoenix_install()
  end

  defp run_ecto_install(args) do
    Ecto.Install.run(args)

    args
  end

  defp run_phoenix_install(args) do
    Phoenix.Install.run(args, schema_opts(args))
  end

  defp schema_opts({_config, parsed, _invalid}) do
    Pow.schema_options_from_args(parsed)
  end
  defp schema_opts(args) when is_list(args) do
    args
    |> Pow.parse_options([], [])
    |> schema_opts()
  end

  defp no_umbrella! do
    if Project.umbrella?() do
      Mix.raise("mix pow.install can't be used in umbrella apps. Run mix pow.ecto.install in your ecto app directory, and optionally mix pow.phoenix.install in your phoenix app directory.")
    end

    :ok
  end
end
