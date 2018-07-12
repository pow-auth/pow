defmodule Mix.Tasks.Authex.Phoenix.Gen.Templates do
  @shortdoc "Generates authex views and templates"

  @moduledoc """
  Generates authex templates for Phoenix.

      mix authex.phoenix.gen.templates
  """
  use Mix.Task

  alias Mix.{Authex.Utils, Generator, Phoenix}

  @switches [context_app: :string, web_path: :string]
  @default_opts []

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.phoenix.gen.templates")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> create_template_files()
  end

  @template_files [
    {"registration", ~w(new edit show)},
    {"session", ~w(new)}
  ]

  defp create_template_files(config) do
    apps        = [".", :authex]
    binding     = []
    context_app = Map.get(config, :context_app, Mix.Authex.Context.context_app())
    web_prefix  = web_path(context_app)

    Enum.each @template_files, fn {name, files} ->
      create_view_file(name, context_app, web_prefix)
      create_templates(apps, binding, web_prefix, name, files)
    end
  end

  defp create_view_file(name, context_app, web_prefix) do
    path        = Path.join([web_prefix, "views", "authex", "#{name}_view.ex"])
    context_base = Mix.Authex.Context.context_base(context_app)
    mod          = web_module(context_base, web_prefix)

    content     = """
    defmodule #{inspect mod}.Authex.#{Macro.camelize(name)}View do
      use #{inspect mod}, :view
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

  defp web_path(this_app), do: Path.join("lib", "#{this_app}_web")

  defp web_module(base, web_prefix) do
    case String.ends_with?(web_prefix, "_web") do
      true  -> Module.concat(["#{base}Web"])
      false -> Module.concat([base])
    end
  end
end
