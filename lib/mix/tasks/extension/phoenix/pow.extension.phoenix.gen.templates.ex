defmodule Mix.Tasks.Pow.Extension.Phoenix.Gen.Templates do
  @shortdoc "Generates pow extension views and templates"

  @moduledoc """
  Generates pow extension templates for Phoenix.

      mix pow.extension.phoenix.gen.templates
  """
  use Mix.Task

  alias Mix.Pow.{Phoenix, Utils}

  @switches [context_app: :string]
  @default_opts []

  @doc false
  def run(args) do
    Utils.no_umbrella!("pow.extension.phoenix.gen.templates")

    args
    |> Utils.parse_options(@switches, @default_opts)
    |> create_template_files()
  end

  @extension_templates [
    {PowResetPassword, [
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
