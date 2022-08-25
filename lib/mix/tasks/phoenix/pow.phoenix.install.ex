defmodule Mix.Tasks.Pow.Phoenix.Install do
  @shortdoc "Prints instructions for setting up Pow with Phoenix"

  @moduledoc """
  Prints instructions fo setting up Pow with Phoenix.

      mix pow.phoenix.install -r MyApp.Repo

      mix pow.phoenix.install -r MyApp.Repo --context-app :my_app

      mix pow.phoenix.install -r MyApp.Repo --templates --extension PowResetPassword

  Templates are only generated when `--templates` argument is provided.

  See `Mix.Tasks.Pow.Phoenix.Gen.Templates` and
  `Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates` for more.

  ## Arguments

    * `--context-app` - app to use for path and module names
    * `--templates` - generate templates and views
    * `--extension` - extensions to generate templates for
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Phoenix}
  alias Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates, as: PhoenixExtensionTemplatesTask
  alias Mix.Tasks.Pow.Phoenix.Gen.Templates, as: PhoenixTemplatesTask

  @switches [context_app: :string, templates: :boolean, extension: :keep]
  @default_opts [templates: false]
  @mix_task "pow.phoenix.install"

  @impl true
  def run(args), do: run(args, Pow.schema_options_from_args())

  @doc false
  def run(args, schema_opts) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse_structure()
    |> print_shell_instructions(schema_opts)
    |> maybe_run_gen_templates(args)
    |> maybe_run_extensions_gen_templates(args)
  end

  defp parse_structure({config, _parsed, _invalid}) do
    Map.put(config, :structure, Phoenix.parse_structure(config))
  end

  defp print_shell_instructions(%{structure: structure} = config, schema_opts) do
    [
      config_file_injection(structure, schema_opts),
      phoenix_endpoint_file_injection(structure),
      phoenix_router_file_injection(structure)
    ]
    |> Pow.inject_files()
    |> case do
      :ok ->
        Mix.shell().info("Pow has been installed in your Phoenix app!")
        config

      :error ->
        Mix.raise "Couldn't install Pow! Did you run this inside your Phoenix app?"
    end
  end

  defp config_file_injection(structure, schema_opts) do
    file = Path.expand(Keyword.fetch!(Mix.Project.config(), :config_path))

    content =
      """
      config #{inspect(structure.web_app)}, :pow,
        user: #{inspect(structure.context_base)}.#{schema_opts.schema_name},
        repo: #{inspect(structure.context_base)}.Repo
      """

    %{
      file: file,
      injections: [%{
        content: content,
        test: "config #{inspect(structure.web_app)}, :pow",
        needle: "import_config",
        prepend: true
      }],
      instructions:
        """
        Append this to #{Path.relative_to_cwd(file)}:

        #{content}
        """
    }
  end

  defp phoenix_endpoint_file_injection(structure) do
    file = Path.expand("#{structure.web_prefix}/endpoint.ex")
    content = "  plug Pow.Plug.Session, otp_app: #{inspect(structure.web_app)}"

    %{
      file: file,
      injections: [%{
        content: content,
        test: "plug Pow.Plug.Session",
        needle: "plug Plug.Session"
      }],
      instructions:
        """
        Add the `Pow.Plug.Session` plug to #{Path.relative_to_cwd(file)} after the `Plug.Session` plug:

        defmodule #{inspect(structure.web_module)}.Endpoint do
          use Phoenix.Endpoint, otp_app: #{inspect(structure.web_app)}

          # ...

          plug Plug.Session, @session_options
        #{content}
          plug #{inspect(structure.web_module)}.Router
        end
        """
    }
  end

  defp phoenix_router_file_injection(structure) do
    file = Path.expand("#{structure.web_prefix}/router.ex")

    router_use_content = "  use Pow.Phoenix.Router"
    router_scope_content =
      """
        scope "/" do
          pipe_through :browser

          pow_routes()
        end
      """

    %{
      file: file,
      injections: [
        %{
          content: router_use_content,
          test: "use Pow.Phoenix.Router",
          needle: "use #{inspect(structure.web_module)}, :router"
        },
        %{
          content: router_scope_content,
          test: "pow_routes()",
          needle: "scope ",
          prepend: true,
        }
      ],
      instructions:
        """
        Update `#{Path.relative_to_cwd(file)}` with the Pow routes:

        defmodule #{inspect(structure.web_module)}.Router do
          use #{inspect(structure.web_module)}, :router
        #{router_use_content}

          # ... pipelines

        #{router_scope_content}

          # ... routes
        end
        """
    }
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
end
