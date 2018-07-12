defmodule Mix.Tasks.Authex.Phoenix.Install do
  @shortdoc "Generates user schema module, migrations file, templates and views"

  @moduledoc """
  Generates a user schema module and migrations file by default

      mix authex.phoenix.install -r MyApp.Repo

  If you wish to generate templates and views you should add the `--templates`
  option.
  """
  use Mix.Task

  alias Mix.Tasks.Authex.{Ecto, Phoenix.Gen}
  alias Mix.Authex.Utils

  @switches [migrations: :boolean, schema: :boolean, templates: :boolean]
  @default_opts [migrations: true, schema: true, templates: false]

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.ecto.install")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> run_ecto_install(args)
    |> maybe_run_gen_templates(args)
    |> print_shell_instructions()
  end

  defp run_ecto_install(config, args) do
    Ecto.Install.run(args)

    config
  end

  defp maybe_run_gen_templates(%{templates: true} = config, args) do
    Gen.Templates.run(args)

    config
  end
  defp maybe_run_gen_templates(config, _args), do: config

  defp print_shell_instructions(_config) do
    Mix.shell.info """
    Configure your router.ex file the following way:

    defmodule MyAppWeb.Router do
      use MyAppWeb, :router
      use Authex.Router

      pipeline :browser do
        # ...
        use Authex.Authorization.Plug.Session.Plug.Session,
          user: MyApp.User
      end

      pipeline :protected do
        use Authex.Authroization.Plug.EnsureAuthenticated
      end

      scope "/", MyAppWeb do
        pipe_through :browser
        authex_routes()

        # ...
      end

      scope "/", MyAppWeb do
        pipe_through [:browser, :protected]

        # ...
      end
    end
    """
  end
end
