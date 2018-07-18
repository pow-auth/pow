defmodule Mix.Tasks.Authex.Extension.Phoenix.Gen.Templates do
  @shortdoc "Generates authex extension views and templates"

  @moduledoc """
  Generates authex extension templates for Phoenix.

      mix authex.extension.phoenix.gen.templates
  """
  use Mix.Task

  alias Mix.Authex.{Phoenix, Utils}

  @switches [context_app: :string]
  @default_opts []

  @doc false
  def run(args) do
    Utils.no_umbrella!("authex.extension.phoenix.gen.templates")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> create_template_files()
  end

  @extension_templates [
    {AuthexResetPassword, [
      {"reset_password", ~w(new edit)}
    ]}
  ]
  defp create_template_files(config) do
    structure    = Phoenix.Utils.parse_structure(config)
    context_base = structure[:context_base]
    web_module   = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Enum.each @extension_templates, fn {module, templates} ->
      Enum.each templates, fn {name, actions} ->
        Phoenix.Utils.create_view_file(module, name, web_module, web_prefix)
        Phoenix.Utils.create_templates(module, name, web_prefix, actions)
      end
    end

    %{context_base: context_base, web_module: web_module}
  end
end
