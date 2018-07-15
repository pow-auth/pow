defmodule Mix.Tasks.Authex.Phoenix.Install do
  @shortdoc "Generates user schema module, migrations file, templates and views"

  @moduledoc """
  Generates a user schema module and migrations file by default

      mix authex.phoenix.install -r MyApp.Repo

  If you wish to generate templates and views you should add
  `--templates` as argument.
  """
  use Mix.Task

  alias Mix.Tasks.Authex.{Ecto, Phoenix.Gen}
  alias Mix.Authex.Utils

  @switches [migrations: :boolean, schema: :boolean, templates: :boolean]
  @default_opts [migrations: true, schema: true, templates: false]

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.phoenix.install")

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

  defp print_shell_instructions(config) do
    structure = Mix.Authex.Phoenix.Utils.parse_structure(config)
    mod       = structure[:context_base]
    web_mod   = structure[:web_module]

    Mix.shell.info """
    Authex has been installed in your phoenix app! There's
    two files you'll need to configure first before you can
    use Authex.

    First, the endpoint.ex file needs to have the `Authex.Plug`:

    defmodule #{inspect web_mod}.Endpoint do
      use Phoenix.Endpoint, otp_app: :#{Macro.underscore(mod)}

      # ...

      plug Plug.Session,
        store: :cookie,
        key: "_my_project_demo_key",
        signing_salt: "secret"

      plug Authex.Plug.Session,
        repo: #{mod}.Repo,
        user: #{mod}.Users.User

      # ...
    end

    Next, your router.ex should include the Authex routes:

    defmodule #{inspect web_mod}.Router do
      use #{inspect web_mod}, :router
      use Authex.Phoenix.Router

      # ...

      scope "/" do
        pipe_through :browser

        authex_routes()
      end

      # ...
    end

    Remember to run the migrations with `mix ecto.setup`. Happy coding!
    """
  end
end
