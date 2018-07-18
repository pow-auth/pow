defmodule Mix.Tasks.Authex.Install do
  @shortdoc "Generates authex module, user schema module, migrations file"

  @moduledoc """
  Generates a user schema module and migrations file by default

      mix authex.install -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.Tasks.Authex.Ecto
  alias Mix.Generator
  alias Mix.Authex.Utils

  @switches [context_app: :string]

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.install")

    args
    |> Utils.parse_options(@switches, [])
    |> create_authex_module()
    |> run_ecto_install(args)
  end

  defp run_ecto_install(config, args) do
    Ecto.Install.run(args)

    config
  end

  defp create_authex_module(config) do
    context_app  = Map.get(config, :context_app, Utils.context_app())
    context_base = Utils.context_base(context_app)

    file_name = "authex.ex"
    content   = """
    defmodule #{context_base}.Authex do
      use Authex,
        user: #{context_base}.Users.User,
        repo: #{context_base}.Repo
    end
    """

    context_app
    |> Utils.context_lib_path("")
    |> Path.join(file_name)
    |> Generator.create_file(content)

    config
  end
end
