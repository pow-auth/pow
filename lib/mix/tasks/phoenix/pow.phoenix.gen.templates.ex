defmodule Mix.Tasks.Pow.Phoenix.Gen.Templates do
  @shortdoc "Generates Pow views and templates"

  @moduledoc """
  Generates pow templates for Phoenix.

      mix pow.phoenix.gen.templates

  ## Arguments

    * `--context-app MyApp` app to use for path and module names
  """
  use Mix.Task

  alias Mix.{Pow, Pow.Phoenix}

  @switches [context_app: :string]
  @default_opts []

  @doc false
  def run(args) do
    Pow.no_umbrella!("pow.phoenix.gen.templates")

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> create_template_files()
    |> print_shell_instructions()
  end

  @templates [
    {"registration", ~w(new edit)},
    {"session", ~w(new)}
  ]

  defp create_template_files(config) do
    structure    = Phoenix.parse_structure(config)
    context_base = structure[:context_base]
    web_module   = structure[:web_module]
    web_prefix   = structure[:web_prefix]

    Enum.each @templates, fn {name, actions} ->
      Phoenix.create_view_file(Elixir.Pow, name, web_module, web_prefix)
      Phoenix.create_templates(Elixir.Pow, name, web_prefix, actions)
    end

    %{context_base: context_base, web_module: web_module}
  end

  defp print_shell_instructions(%{context_base: mod, web_module: web_mod}) do
    Mix.shell.info """
    All Pow templates and views has been generated.

    Please update set `web_module: #{inspect web_mod}` in your configuration,
    like so:

    defmodule #{inspect web_mod}.Endpoint do
      use #{inspect web_mod}.Endpoint, otp_app: :#{Macro.underscore(mod)}

      # ...

      plug Pow.Plug.Session,
        repo: #{mod}.Repo,
        user: #{mod}.Users.User,
        web_module: #{inspect web_mod}

      # ...
    end
    """
  end
end
