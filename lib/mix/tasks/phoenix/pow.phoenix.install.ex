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
  alias Mix.{Pow, Pow.Phoenix}

  @switches [context_app: :string, migrations: :boolean, schema: :boolean, templates: :boolean, extension: :keep]
  @default_opts [migrations: true, schema: true, templates: false]
  @mix_task "pow.phoenix.install"

  @doc false
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse_structure()
    |> maybe_run_gen_templates(args)
    |> maybe_run_extensions_gen_templates(args)
    |> print_shell_instructions()
  end

  defp parse_structure({config, _parsed, _invalid}) do
    Map.put(config, :structure, Phoenix.parse_structure(config))
  end

  defp maybe_run_gen_templates(%{templates: true} = config, args) do
    PhoenixTemplatesTask.run(args)

    config
  end
  defp maybe_run_gen_templates(config, _args), do: config

  defp maybe_run_extensions_gen_templates(%{templates: true, extension: extensions} = config, args) when extensions != [] do
    PhoenixExtensionTemplatesTask.run(args)

    config
  end
  defp maybe_run_extensions_gen_templates(config, _args), do: config

  defp print_shell_instructions(%{structure: structure}) do
    context_base = structure[:context_base]
    web_base     = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Mix.shell.info("""
    Pow has been installed in your phoenix app!

    There are three files you'll need to configure first before you can use Pow.

    First, append this to `config/config.ex`:

    config :#{Macro.underscore(context_base)}, :pow,
      user: #{inspect(context_base)}.Users.User,
      repo: #{inspect(context_base)}.Repo

    Next, add `Pow.Plug.Session` plug to `#{web_prefix}/endpoint.ex`:

    defmodule #{inspect(web_base)}.Endpoint do
      use Phoenix.Endpoint, otp_app: :#{Macro.underscore(context_base)}

      # ...

      plug Plug.Session,
        store: :cookie,
        key: "_#{Macro.underscore(context_base)}_key",
        signing_salt: "secret"

      plug Pow.Plug.Session, otp_app: :#{Macro.underscore(context_base)}

      # ...
    end

    Last, update` #{web_prefix}/router.ex` with the Pow routes:

    defmodule #{inspect(web_base)}.Router do
      use #{inspect(web_base)}, :router
      use Pow.Phoenix.Router

      # ... pipelines

      scope "/" do
        pipe_through :browser

        pow_routes()
      end

      # ... routes
    end
    """)
  end
end
