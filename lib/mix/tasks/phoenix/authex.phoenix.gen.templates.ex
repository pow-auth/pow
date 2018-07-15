defmodule Mix.Tasks.Authex.Phoenix.Gen.Templates do
  @shortdoc "Generates authex views and templates"

  @moduledoc """
  Generates authex templates for Phoenix.

      mix authex.phoenix.gen.templates
  """
  use Mix.Task

  alias Mix.{Authex.Utils, Generator, Phoenix}

  @switches [context_app: :string]
  @default_opts []

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.phoenix.gen.templates")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> create_template_files()
    |> print_shell_instructions()
  end

  @template_files [
    {"registration", ~w(new edit show)},
    {"session", ~w(new)}
  ]

  defp create_template_files(config) do
    apps         = [".", :authex]
    binding      = []
    structure    = Mix.Authex.Phoenix.Utils.parse_structure(config)
    context_base = structure[:context_base]
    web_module   = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Enum.each @template_files, fn {name, files} ->
      create_view_file(name, web_module, web_prefix)
      create_templates(apps, binding, web_prefix, name, files)
    end

    %{context_base: context_base, web_module: web_module}
  end

  defp create_view_file(name, web_mod, web_prefix) do
    path        = Path.join([web_prefix, "views", "authex", "#{name}_view.ex"])

    content     = """
    defmodule #{inspect web_mod}.Authex.#{Macro.camelize(name)}View do
      use #{inspect web_mod}, :view
    end
    """

    Generator.create_file(path, content)
  end

  defp create_templates(apps, binding, web_prefix, name, files) do
    source_dir = "priv/phoenix/templates"
    templates_path = Path.join([web_prefix, "templates", "authex", name])
    mapping = Enum.map(files, &templates_mapping(&1, name, templates_path))

    Phoenix.copy_from(apps, source_dir, binding, mapping)
  end

  defp templates_mapping(file, source_path, dest_path) do
    file   = "#{file}.html.eex"
    source = Path.join(source_path, file)
    dest   = Path.join(dest_path, file)

    {:text, source, dest}
  end

  defp print_shell_instructions(%{context_base: mod, web_module: web_mod}) do
    Mix.shell.info """
    All Authex templates and views has been generated.

    Please update set `web_module: #{inspect web_mod}` in your configuration,
    like so:

    defmodule #{inspect web_mod}.Endpoint do
      use #{inspect web_mod}.Endpoint, otp_app: :#{Macro.underscore(mod)}

      # ...

      plug Authex.Plug.Session,
        repo: #{mod}.Repo,
        user: #{mod}.Users.User,
        web_module: #{inspect web_mod}

      # ...
    end
    """
  end
end
