defmodule Mix.Tasks.Authex.Phoenix.Gen.Templates do
  @shortdoc "Generates authex views and templates"

  @moduledoc """
  Generates authex templates for Phoenix.

      mix authex.phoenix.gen.templates
  """
  use Mix.Task

  alias Mix.{Authex.Utils, Generator}

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

  @templates [
    {"registration", ~w(new edit)},
    {"session", ~w(new)}
  ]

  defp create_template_files(config) do
    structure    = Mix.Authex.Phoenix.Utils.parse_structure(config)
    context_base = structure[:context_base]
    web_module   = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Enum.each @templates, fn {name, actions} ->
      create_view_file(name, web_module, web_prefix)
      create_templates(name, web_prefix, actions)
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

  defp create_templates(name, web_prefix, actions) do
    path = Path.join([web_prefix, "templates", "authex", name])
    template_module = Module.concat([Authex.Phoenix, "#{Macro.camelize(name)}Template"])

    actions
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.each(fn action ->
      content   = template_module.html(action)
      file_path = Path.join(path, "#{action}.html.eex")

      Generator.create_file(file_path, content)
    end)
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
