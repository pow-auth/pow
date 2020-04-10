defmodule Mix.Tasks.Pow.Extension.Ecto.Gen.Migrations do
  @shortdoc "Generates user migration files for extensions"

  @moduledoc """
  Generates user migration files for extensions.

      mix pow.extension.ecto.gen.migrations -r MyApp.Repo --extension PowEmailConfirmation --extension PowResetPassword

      mix pow.extension.ecto.gen.migrations -r MyApp.Repo --extension PowEmailConfirmation Accounts.Account accounts

  ## Arguments

    * `-r`, `--repo` - the repo module
    * `--extension` - the extension to generate the migration for
    * `--binary-id` - use binary id for primary key
  """
  use Mix.Task

  alias Pow.Extension.Ecto.Schema.Migration, as: SchemaMigration
  alias Mix.{Ecto, Pow, Pow.Ecto.Migration, Pow.Extension}

  @switches [binary_id: :boolean, extension: :keep]
  @default_opts [binary_id: false]
  @mix_task "pow.extension.ecto.gen.migrations"

  @impl true
  def run(args) do
    Pow.no_umbrella!(@mix_task)
    Pow.ensure_ecto!(@mix_task, args)

    args
    |> Pow.parse_options(@switches, @default_opts)
    |> parse()
    |> create_migration_files(args)
    |> print_shell_instructions()
  end

  defp parse({config, parsed, _invalid}) do
    case parsed do
      [_schema_name, schema_plural | _rest] ->
        Map.merge(config, %{schema_plural: schema_plural})

      _ ->
        config
    end
  end

  defp create_migration_files(config, args) do
    context_base = Pow.app_base(Pow.otp_app())
    context_app  = String.to_atom(Macro.underscore(context_base))
    extensions   = Extension.extensions(config, context_app)

    args
    |> Ecto.parse_repo()
    |> Enum.map(&Ecto.ensure_repo(&1, args))
    |> Enum.map(&Map.put(config, :repo, &1))
    |> Enum.each(&create_extension_migration_files(&1, extensions, context_base))

    %{extensions: extensions, context_app: context_app}
  end

  defp create_extension_migration_files(config, extensions, context_base) do
    for extension <- extensions, do: create_migration_file(config, extension, context_base)
  end

  defp create_migration_file(%{repo: repo, binary_id: binary_id} = config, extension, context_base) do
    schema_plural = Map.get(config, :schema_plural, "users")
    schema        = SchemaMigration.new(extension, context_base, schema_plural, repo: repo, binary_id: binary_id)
    content       = SchemaMigration.gen(schema)

    case empty?(schema) do
      true  -> Mix.shell().info("Notice: No migration file will be generated for #{inspect extension} as this extension doesn't require any migrations.")
      false -> Migration.create_migration_file(repo, schema.migration_name, content)
    end
  end

  defp empty?(%{assocs: [], attrs: [], indexes: []}),
    do: true
  defp empty?(_schema), do: false

  defp print_shell_instructions(%{extensions: [], context_app: context_app}) do
    Extension.no_extensions_error(context_app)
  end
  defp print_shell_instructions(config), do: config
end
