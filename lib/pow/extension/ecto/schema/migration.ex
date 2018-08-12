defmodule Pow.Extension.Ecto.Schema.Migration do
  @moduledoc """
  Generates schema migration content for extensions.
  """
  alias Pow.{Config, Ecto.Schema.Migration, Extension.Ecto.Schema}

  @template """
  defmodule <%= inspect schema.repo %>.Migrations.<%= schema.migration_name %> do
    use Ecto.Migration

    def change do
      alter table(:<%= schema.table %>) do<%= for {k, v} <- schema.attrs do %>
        add <%= inspect k %>, <%= inspect v %><%= schema.migration_defaults[k] %><% end %><%= for {_, i, _, s} <- schema.assocs do %>
        add <%= if(String.ends_with?(inspect(i), "_id"), do: inspect(i), else: inspect(i) <> "_id") %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if schema.binary_id do %>, type: :binary_id<% end %>)<% end %>
      end
  <%= for index <- schema.indexes do %>
      <%= index %><% end %>
    end
  end
  """

  @doc """
  Generates migration schema map.
  """
  @spec new(atom(), atom(), binary(), Config.t()) :: map()
  def new(extension, context_base, schema_plural, config \\ []) do
    repo           = Config.get(config, :repo, Module.concat([context_base, "Repo"]))
    config         = Config.put(config, :extensions, [extension])
    attrs          = Schema.attrs(config)
    indexes        = Schema.indexes(config)
    migration_name = name(extension, schema_plural)

    Migration.schema(context_base, repo, schema_plural, migration_name, attrs, indexes, config)
  end

  defp name(extension, table) do
    extension_name =
      extension
      |> Module.split()
      |> List.last()

    "Add#{extension_name}To#{Macro.camelize(table)}"
  end

  @doc """
  Generates migration file content.
  """
  @spec gen(map()) :: binary()
  def gen(schema) do
    EEx.eval_string(unquote(@template), schema: schema)
  end
end
