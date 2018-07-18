defmodule Authex.Extension.Ecto.Schema.Migration do
  @moduledoc """
  Generates schema migration content for extensions.
  """
  alias Authex.{Config,
                Ecto.Schema.Migration,
                Extension.Ecto.Schema}

  @template """
    defmodule <%= inspect schema.repo %>.Migrations.<%= schema.migration_name %> do
      use Ecto.Migration

      def change do
        alter table(:<%= schema.table %>) do
    <%= for {k, v} <- schema.attrs do %>      add <%= inspect k %>, <%= inspect v %><%= schema.migration_defaults[k] %>
    <% end %><%= for {_, i, _, s} <- schema.assocs do %>      add <%= if(String.ends_with?(inspect(i), "_id"), do: inspect(i), else: inspect(i) <> "_id") %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if schema.binary_id do %>, type: :binary_id<% end %>)
    <% end %>
        end
    <%= for index <- schema.indexes do %>
        <%= index %><% end %>
      end
    end
    """

  @spec gen(atom(), binary(), Config.t()) :: binary()
  def gen(extension, context_base, config \\ []) do
    context_base
    |> parse_options(extension, config)
    |> migration_file(extension)
  end

  def name(extension, table) do
    "Add#{extension}To#{Macro.camelize(table)}"
  end

  defp parse_options(base, extension, config) do
    repo           = Config.get(config, :repo, Module.concat([base, "Repo"]))
    table          = Config.get(config, :table, "users")
    attrs          = Schema.attrs([extensions: [extension]], :email)
    indexes        = Schema.indexes(extensions: [extension])
    migration_name = name(extension, table)

    Migration.schema(repo, table, migration_name, attrs, indexes, binary_id: config[:binary_id])
  end

  defp migration_file(schema, extension) do
    EEx.eval_string(unquote(@template), schema: schema, extension: extension)
  end
end
