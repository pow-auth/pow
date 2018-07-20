defmodule Mix.Tasks.Pow.Phoenix.Install do
  @shortdoc "Generates user schema module, migrations file, templates and views"

  @moduledoc """
  Generates a user schema module and migrations file by default

      mix pow.phoenix.install -r MyApp.Repo

  If you wish to generate templates and views you should add
  `--templates` as argument.
  """
  use Mix.Task

  alias Mix.Tasks.{Pow, Pow.Extension, Pow.Phoenix.Gen}
  alias Mix.Pow.Utils

  @switches [migrations: :boolean, schema: :boolean, templates: :boolean, extension: :keep]
  @default_opts [migrations: true, schema: true, templates: false]

  @doc false
  def run(args) do
    Utils.no_umbrella!("pow.phoenix.install")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> run_pow_install(args)
    |> maybe_run_gen_templates(args)
    |> maybe_run_extensions_gen_templates(args)
    |> print_shell_instructions()
  end

  defp run_pow_install(config, args) do
    Pow.Install.run(args)

    config
  end

  defp maybe_run_gen_templates(%{templates: true} = config, args) do
    Gen.Templates.run(args)

    config
  end
  defp maybe_run_gen_templates(config, _args), do: config

  defp maybe_run_extensions_gen_templates(%{templates: true} = config, args) do
    Extension.Phoenix.Gen.Templates.run(args)

    config
  end
  defp maybe_run_extensions_gen_templates(config, _args), do: config

  defp print_shell_instructions(config) do
    structure = Mix.Pow.Phoenix.Utils.parse_structure(config)
    mod       = structure[:context_base]
    web_mod   = structure[:web_module]

    Mix.shell.info """
    Pow has been installed in your phoenix app! There's
    two files you'll need to configure first before you can
    use Pow.

    First, the endpoint.ex file needs to have the `Pow.Plug`:

    defmodule #{inspect web_mod}.Endpoint do
      use Phoenix.Endpoint, otp_app: :#{Macro.underscore(mod)}

      # ...

      plug Plug.Session,
        store: :cookie,
        key: "_my_project_demo_key",
        signing_salt: "secret"

      plug Pow.Plug.Session,
        repo: #{mod}.Repo,
        user: #{mod}.Users.User

      # ...
    end

    Next, your router.ex should include the Pow routes:

    defmodule #{inspect web_mod}.Router do
      use #{inspect web_mod}, :router
      use Pow.Phoenix.Router

      # ...

      scope "/" do
        pipe_through :browser

        pow_routes()
      end

      # ...
    end

    Remember to run the migrations with `mix ecto.setup`. Happy coding!
    """
  end
end
