defmodule Mix.Tasks.Pow.Phoenix.Gen.Templates do
  @shortdoc "Generates views and templates"

  @moduledoc """
  Generates views and templates.

      mix pow.phoenix.gen.templates

      mix pow.phoenix.gen.templates --context-app my_app

  ## Arguments

    * `--context-app` - app to use for path and module names
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Phoenix}

  @switches [context_app: :string]
  @default_opts []
  @mix_task "pow.phoenix.gen.templates"

  @impl true
  def run(args), do: run(args, Pow.schema_options_from_args())

  @doc false
  def run(args, schema_opts) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_phoenix!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_template_files()
    |> print_shell_instructions(schema_opts)
  end

  @templates [
    {"registration", ~w(new edit)},
    {"session", ~w(new)}
  ]

  defp create_template_files({config, _parsed, _invalid}) do
    structure  = Phoenix.parse_structure(config)
    web_module = structure[:web_module]
    web_prefix = structure[:web_prefix]

    Enum.each(@templates, fn {name, actions} ->
      Phoenix.create_view_file(Elixir.Pow, name, web_module, web_prefix)
      Phoenix.create_templates(Elixir.Pow, name, web_prefix, actions)
    end)

    Mix.shell().info("Pow Phoenix templates and views has been generated.")

    %{structure: structure}
  end

  defp print_shell_instructions(%{structure: structure} = config, schema_opts) do
    case Pow.inject_files([config_file_injection(structure, schema_opts)]) do
      :ok ->
        config

      :error ->
        Mix.raise "Couldn't configure Pow! Did you run this inside your Phoenix app?"
    end
  end

  defp config_file_injection(structure, schema_opts) do
    file = Path.expand(Keyword.fetch!(Mix.Project.config(), :config_path))
    content = "  web_module: #{inspect(structure.web_module)},"

    %{
      file: file,
      injections: [%{
        content: content,
        test: "web_module: #{inspect(structure.web_module)}",
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
end
