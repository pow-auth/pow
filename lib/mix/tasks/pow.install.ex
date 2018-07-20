defmodule Mix.Tasks.Pow.Install do
  @shortdoc "Generates pow module, user schema module, migrations file"

  @moduledoc """
  Generates a user schema module and migrations file by default

      mix pow.install -r MyApp.Repo
  """
  use Mix.Task

  alias Mix.Tasks.Pow.Ecto
  alias Mix.Generator
  alias Mix.Pow.Utils

  @switches [context_app: :string]

  @doc false
  def run(args) do
    Utils.no_umbrella!("pow.install")

    args
    |> Utils.parse_options(@switches, [])
    |> create_pow_module()
    |> run_ecto_install(args)
  end

  defp run_ecto_install(config, args) do
    Ecto.Install.run(args)

    config
  end

  defp create_pow_module(config) do
    context_app  = Map.get(config, :context_app, Utils.context_app())
    context_base = Utils.context_base(context_app)

    file_name = "pow.ex"
    content   = """
    defmodule #{context_base}.Pow do
      use Pow,
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
