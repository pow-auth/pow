defmodule Mix.Tasks.Pow.Install do
  @shortdoc "Installs Pow"

  @moduledoc """
  Will generate pow module files, a user schema module, migrations file.

      mix pow.install -r MyApp.Repo

  ## Arguments

    * `--templates` generate templates and views
    * `--no-migrations` don't generate migration files
    * `--no-schema` don't generate schema file
    * `--extension` extension to generatetemplates and views for
  """
  use Mix.Task

  alias Mix.Generator
  alias Mix.{Pow, Pow.Extension}
  alias Mix.Tasks.Pow.{Ecto, Phoenix}

  @switches [context_app: :string, extension: :keep]
  @default_opts []

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow.install")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> gen_context_module()
    |> run_ecto_install(args)
    |> run_phoenix_install(args)
  end

  defp gen_context_module(config) do
    context_app  = Map.get(config, :context_app, Pow.context_app())
    context_base = Pow.context_base(context_app)
    extensions   = Extension.extensions(config)

    file_name = "pow.ex"
    content   = """
    defmodule #{inspect context_base}.Pow do
      use Pow, :context,
        extensions: #{inspect(extensions)}
    end
    """

    context_app
    |> Pow.context_lib_path("")
    |> Path.join(file_name)
    |> Generator.create_file(content)

    config
  end

  defp run_ecto_install(config, args) do
    Ecto.Install.run(args)

    config
  end

  defp run_phoenix_install(config, args) do
    Phoenix.Install.run(args)

    config
  end
end
