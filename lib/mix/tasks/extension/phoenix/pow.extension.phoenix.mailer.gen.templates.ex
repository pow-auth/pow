defmodule Mix.Tasks.Pow.Extension.Phoenix.Mailer.Gen.Templates do
  @shortdoc "Generates Pow mailer extension views and templates"

  @moduledoc """
  Generates Pow mailer extension templates for Phoenix.

      mix pow.extension.phoenix.mailer.gen.templates
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Extension, Pow.Phoenix, Pow.Phoenix.Mailer}

  @switches [context_app: :string, extension: :keep]
  @default_opts []

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow.extension.phoenix.mailer.gen.templates")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_template_files()
    |> print_shell_instructions()
  end

  @extension_templates [
    {PowResetPassword, [
      {"mailer", ~w(reset_password)}
    ]},
    {PowEmailConfirmation, [
      {"mailer", ~w(email_confirmation)}
    ]}
  ]
  defp create_template_files({config, _parsed, _invalid}) do
    structure    = Phoenix.parse_structure(config)
    web_module   = structure[:web_module]
    web_prefix   = structure[:web_prefix]
    extensions   =
      config
      |> Extension.extensions()
      |> Enum.filter(&Keyword.has_key?(@extension_templates, &1))
      |> Enum.map(&{&1, @extension_templates[&1]})

    Enum.each(extensions, fn {module, templates} ->
      Enum.each(templates, fn {name, mails} ->
        mails = Enum.map(mails, &String.to_existing_atom/1)
        Mailer.create_view_file(module, name, web_module, web_prefix, mails)
        Mailer.create_templates(module, name, web_prefix, mails)
      end)
    end)

    %{structure: structure}
  end

  defp print_shell_instructions(%{structure: structure}) do
    web_base     = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Mix.shell.info("""
    Pow mailer templates has been installed in your phoenix app!

    You'll need to set up #{web_prefix}.ex with a `:mailer_view` macro:

    defmodule #{inspect(web_base)} do
      # ...

      def mailer_view do
        quote do
          use Phoenix.View, root: "#{web_prefix}/templates",
                            namespace: #{inspect(web_base)}

          use Phoenix.HTML
        end
      end

      # ...
    end
    """)
  end
end
