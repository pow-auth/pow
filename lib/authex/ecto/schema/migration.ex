defmodule Authex.Ecto.Schema.Migration do
  @moduledoc """
  Generates schema migration content.
  """
  alias Authex.{Config, Ecto.Schema.Fields}

  @template """
    defmodule <%= inspect schema.repo %>.Migrations.<%= schema.migration_name %> do
      use Ecto.Migration

      def change do
        create table(:<%= schema.table %><%= if schema.binary_id do %>, primary_key: false<% end %>) do
    <%= if schema.binary_id do %>      add :id, :binary_id, primary_key: true
    <% end %><%= for {k, v} <- schema.attrs do %>      add <%= inspect k %>, <%= inspect v %><%= schema.migration_defaults[k] %>
    <% end %><%= for {_, i, _, s} <- schema.assocs do %>      add <%= if(String.ends_with?(inspect(i), "_id"), do: inspect(i), else: inspect(i) <> "_id") %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if schema.binary_id do %>, type: :binary_id<% end %>)
    <% end %>
          timestamps()
        end
    <%= for index <- schema.indexes do %>
        <%= index %><% end %>
      end
    end
    """

  @spec gen(binary(), Config.t()) :: binary()
  def gen(context_base, config \\ []) do
    context_base
    |> parse_options(config)
    |> migration_file()
  end

  @spec name(binary()) :: binary()
  def name(table), do: "Create#{Macro.camelize(table)}"

  defp parse_options(base, config) do
    repo           = Config.get(config, :repo, Module.concat([base, "Repo"]))
    table          = Config.get(config, :table, "users")
    attrs          = Fields.attrs(config)
    indexes        = Fields.indexes(config)
    migration_name = name(table)

    schema(repo, table, migration_name, attrs, indexes, binary_id: config[:binary_id])
  end

  @spec schema(atom(), binary(), binary(), list(), list(), Keyword.t()) :: map()
  def schema(repo, table, migration_name, attrs, indexes, opts) do
    migration_attrs    = migration_attrs(attrs)
    binary_id          = opts[:binary_id]
    migration_defaults = defaults(migration_attrs)
    {assocs, attrs}    = partition_attrs(migration_attrs)
    indexes            = migration_indexes(indexes, table)

    %{
      migration_name: migration_name,
      repo: repo,
      table: table,
      binary_id: binary_id,
      attrs: attrs,
      migration_defaults: migration_defaults,
      assocs: assocs,
      indexes: indexes
    }
  end

  defp migration_attrs(attrs) do
    attrs
    |> Enum.reject(&is_virtual?/1)
    |> Enum.map(&to_migration_attr/1)
  end

  defp is_virtual?({_name, _type}), do: false
  defp is_virtual?({_name, _type, defaults}) do
    Keyword.get(defaults, :virtual, false)
  end

  defp to_migration_attr({name, type}) do
    {name, type, ""}
  end
  defp to_migration_attr({name, type, []}) do
    to_migration_attr({name, type})
  end
  defp to_migration_attr({name, type, defaults}) do
    defaults =
      defaults
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
      |> Enum.join(", ")

    {name, type, ", #{defaults}"}
  end

  defp defaults(attrs) do
    Enum.map(attrs, fn {key, _value, defaults} ->
      {key, defaults}
    end)
  end

  defp partition_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value, _defaults} -> {key, value} end)
    |> Enum.split_with(fn _ -> false end)
  end

  defp migration_indexes(indexes, table) do
    Enum.map(indexes, &to_migration_index(table, &1))
  end

  defp to_migration_index(table, {key, true}),
    do: "create unique_index(:#{table}, [:#{key}])"

  defp migration_file(schema) do
    EEx.eval_string(unquote(@template), schema: schema)
  end
end
