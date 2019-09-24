defmodule Mix.Tasks.Pow.Install do
  @shortdoc "Runs install mix tasks for Ecto and Phoenix"

  @moduledoc """
  Runs install mix tasks for Ecto and Phoenix.

      mix pow.install -r MyApp.Repo

      mix pow.install -r MyApp.Repo Accounts.Account accounts

  See `Mix.Tasks.Pow.Ecto.Install` and `Mix.Tasks.Pow.Phoenix.Install` for
  more.
  """
  use Mix.Task

  alias Mix.{Pow, Project, Tasks.Pow.Ecto, Tasks.Pow.Phoenix}
  @mix_task "pow.install"

  @impl true
  def run(args) do
    no_umbrella!()

    schema_opts = schema_opts(args)

    args
    |> run_ecto_install()
    |> run_phoenix_install(schema_opts)
  end

  defp schema_opts({_config, parsed, _invalid}) do
    Pow.validate_schema_args!(parsed, @mix_task)
  end
  defp schema_opts(args) when is_list(args) do
    args
    |> Pow.parse_options([], [])
    |> schema_opts()
  end

  defp run_ecto_install(args) do
    Ecto.Install.run(args)

    args
  end

  defp run_phoenix_install(args, schema_opts) do
    Phoenix.Install.run(args, schema_opts)
  end

  defp no_umbrella! do
    if Project.umbrella?() do
      Mix.raise(
        """
        mix #{@mix_task} has to be used inside an application directory, but this is an umbrella project.

        Run mix pow.ecto.install inside your Ecto application directory to create schema module and migrations.

        Run mix pow.phoenix.install in your Phoenix application directory for configuration instructions.
        """)
    end

    :ok
  end
end
