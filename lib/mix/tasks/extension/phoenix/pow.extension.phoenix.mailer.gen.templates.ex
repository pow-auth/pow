defmodule Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.Templates do
  @shortdoc "Generates mailer views and templates for extensions"

  @moduledoc """
  Generates mailer views and templates for extensions.

      mix pow.extension.phoenix.mailer.gen.templates --extension PowEmailConfirmation --extension PowResetPassword

  ## Arguments

    * `--extension` - extension to generate templates for
    * `--context-app` - app to use for path and module names
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Extension, Pow.Phoenix, Pow.Phoenix.Mailer}

  @switches [context_app: :string, extension: :keep]
  @default_opts []
  @mix_task "pow.extension.phoenix.mailer.gen.templates"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_template_files()
    |> print_shell_instructions(Pow.schema_options_from_args())
  end

  @extension_templates %{
    PowResetPassword => [
      {"mailer", ~w(reset_password)}
    ],
    PowEmailConfirmation => [
      {"mailer", ~w(email_confirmation)}
    ],
    PowInvitation => [
      {"mailer", ~w(invitation)}
    ]
  }
  defp create_template_files({config, _parsed, _invalid}) do
    structure  = Phoenix.parse_structure(config)
    web_module = structure[:web_module]
    web_prefix = structure[:web_prefix]
    web_app    = structure[:web_app]

    extensions =
      config
      |> Extension.extensions(web_app)
      |> Enum.map(fn extension ->
        templates = Map.get(@extension_templates, extension, [])

        create_views_and_templates(extension, templates, web_module, web_prefix)

        extension
      end)

    %{extensions: extensions, web_app: web_app, structure: structure}
  end

  defp create_views_and_templates(extension, [], _web_module, _web_prefix) do
    Mix.shell().info("Notice: No mailer view or template files will be generated for #{inspect extension} as this extension doesn't have any mailer views defined.")
  end
  defp create_views_and_templates(extension, templates, web_module, web_prefix) do
    Enum.each(templates, fn {name, mails} ->
      mails = Enum.map(mails, &String.to_atom/1)

      Mailer.create_view_file(extension, name, web_module, web_prefix, mails)
      Mailer.create_templates(extension, name, web_prefix, mails)
    end)

    Mix.shell().info("Pow mailer templates has been installed in your phoenix app!")
  end

  defp print_shell_instructions(%{extensions: [], web_app: web_app}, _schema_opts) do
    Extension.no_extensions_error(web_app)
  end
  defp print_shell_instructions(%{structure: structure} = config, schema_opts) do
    [
      config_file_injection(structure, schema_opts),
      web_file_injection(structure)
    ]
    |> Pow.inject_files()
    |> case do
      :ok ->
        config

      :error ->
        Mix.raise "Couldn't configure Pow! Did you run this inside your Phoenix app?"
    end
  end

  defp config_file_injection(structure, schema_opts) do
    file = Path.expand(Keyword.fetch!(Mix.Project.config(), :config_path))
    content = "  web_mailer_module: #{inspect(structure.web_module)},"

    %{
      file: file,
      injections: [%{
        content: content,
        test: "web_mailer_module: #{inspect(structure.web_module)}",
        needle: "config #{inspect(structure.web_app)}, :pow,"
      }],
      instructions:
        """
        Add `#{String.trim(content)}` to your configuration in #{Path.relative_to_cwd(file)}:

        config #{inspect(structure.web_app)}, :pow,
        #{content}
          user: #{inspect(structure.context_base)}.#{schema_opts.schema_name},
          # ...
        """
    }
  end

  defp web_file_injection(structure) do
    file = Path.expand("#{structure.web_prefix}.ex")

    content =
    """
      def mailer_view do
        quote do
          use Phoenix.View, root: "#{structure.web_prefix}/templates",
                            namespace: #{inspect(structure.web_module)}

          use Phoenix.HTML
        end
      end
    """

    %{
      file: file,
      injections: [%{
        content: content,
        test: "def mailer_view do",
        needle: "def router do",
        prepend: true
      }],
      instructions:
        """
        Add `mailer_view/0` to #{Path.relative_to_cwd(file)}:

        defmodule #{inspect(structure.web_module)} do
          # ...

          #{content}

          # ...
        end
        """
    }
  end
end
