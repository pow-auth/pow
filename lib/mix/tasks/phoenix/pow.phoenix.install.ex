defmodule Mix.Tasks.Pow.Phoenix.Install do
  @shortdoc "Generates user schema module, migration files, templates and views"

  @moduledoc """
  Generates a user schema module and migration files.

      mix pow.phoenix.install -r MyApp.Repo

  With `--templates` flag, `Mix.Tasks.Pow.Phoenix.Gen.Templates` and
  `Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates` will be called.

  ## Arguments

    * `--templates` generate templates and views
    * `--extension` extension to generatetemplates and views for
  """
  use Mix.Task

  alias Mix.Tasks.Pow.Phoenix.Gen.Templates, as: PhoenixTemplatesTask
  alias Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates, as: PhoenixExtensionTemplatesTask
  alias Mix.{Generator, Pow, Pow.Phoenix}

  @switches [context_app: :string, migrations: :boolean, schema: :boolean, templates: :boolean, extension: :keep]
  @default_opts [migrations: true, schema: true, templates: false]

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow.phoenix.install")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse_structure()
    |> gen_pow_module()
    |> maybe_run_gen_templates(args)
    |> maybe_run_extensions_gen_templates(args)
    |> print_shell_instructions()
  end

  defp parse_structure(config) do
    Map.put(config, :structure, Phoenix.parse_structure(config))
  end

  defp gen_pow_module(%{structure: structure} = config) do
    context_base = structure[:context_base]
    web_base     = structure[:web_module]
    path         = structure[:web_prefix]
    extensions   = Mix.Pow.Extension.extensions(config)
    content      = """
    defmodule #{inspect web_base}.Pow do
      use Pow.Phoenix,
        user: #{inspect context_base}.Users.User,
        repo: #{inspect context_base}.Repo,
        extensions: #{inspect(extensions)}
    end
    """

    path
    |> Path.join("pow.ex")
    |> Generator.create_file(content)

    config
  end

  defp maybe_run_gen_templates(%{templates: true} = config, args) do
    PhoenixTemplatesTask.run(args)

    config
  end
  defp maybe_run_gen_templates(config, _args), do: config

  defp maybe_run_extensions_gen_templates(%{templates: true} = config, args) do
    PhoenixExtensionTemplatesTask.run(args)

    config
  end
  defp maybe_run_extensions_gen_templates(config, _args), do: config

  defp print_shell_instructions(%{structure: structure}) do
    context_base = structure[:context_base]
    web_base     = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Mix.shell.info """
    Pow has been installed in your phoenix app!

    There's two files you'll need to configure first before you can use Pow.

    First, the #{web_prefix}/endpoint.ex file needs to have the `#{inspect web_base}.Pow.Plug.Session`:

    defmodule #{inspect web_base}.Endpoint do
      use Phoenix.Endpoint, otp_app: :#{Macro.underscore(context_base)}

      # ...

      plug Plug.Session,
        store: :cookie,
        key: "_my_project_demo_key",
        signing_salt: "secret"

      plug #{inspect web_base}.Pow.Plug.Session,
        repo: #{inspect context_base}.Repo,
        user: #{inspect context_base}.Users.User

      # ...
    end

    Next, your router.ex should include the Pow routes:

    defmodule #{inspect web_base}.Router do
      use #{inspect web_base}, :router
      use #{inspect web_base}.Pow.Phoenix.Router

      # ...

      scope "/" do
        pipe_through :browser

        pow_routes()
      end

      # ...
    end
    """
  end
end
