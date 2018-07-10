defmodule Authex.Ecto.UserSchema do
  @moduledoc """
  Handles the Ecto schema and migration file for user.

  ## Usage

  Configure `lib/my_project/user/user.ex` the following way:

      defmodule MyProject.Users.User do
        use Ecto.Schema

        schema "users" do
          field :custom_field, :string

          Authex.Ecto.UserSchema.user_schema(login_field: :email)

          timestamps()
        end
      end

  Remember to add `user: MyProject.Users.User` to configuration.
  """

  @spec user_schema(Keyword.t()) :: [tuple()]
  defmacro user_schema(config \\ []) do
    config
    |> attrs()
    |> Enum.map(&to_schema_attr/1)
  end

  @spec migration_file(Keyword.t()) :: binary()
  def migration_file(config \\ []) do
    config
    |> schema_migration_opts()
    |> schema_migration()
  end

  @attrs [
    {:password_hash, :string},
    {:current_password, :string, virtual: true},
    {:password, :string, virtual: true},
    {:password_confirm, :string, virtual: true},
  ]

  defp attrs(config) do
    login_field = Keyword.get(config, :login_field, :email)

    [{login_field, :string, null: false}]
    |> Enum.concat(@attrs)
  end

  defp to_schema_attr({name, type}) do
    quote do
      field unquote(name), unquote(type)
    end
  end
  defp to_schema_attr({name, type, defaults}) do
    quote do
      field unquote(name), unquote(type), unquote(defaults)
    end
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

  defp partition_attrs(attrs) do
    attrs
    |> Enum.map(fn {key, value, _defaults} -> {key, value} end)
    |> Enum.split_with(fn _ -> false end)
  end

  defp migration_defaults(attrs) do
    Enum.map(attrs, fn {key, _value, defaults} ->
      {key, defaults}
    end)
  end

  defp indexes(table, [{key, _} | _rest]) do
    ["create unique_index(:#{table}, [:#{key}])"]
  end

  defp schema_migration_opts(opts) do
    attrs              = opts |> attrs() |> Enum.reject(&is_virtual?/1) |> Enum.map(&to_migration_attr/1)
    ctx_app            = Keyword.get(opts, :context_app, Mix.Phoenix.context_app())
    base               = Mix.Phoenix.context_base(ctx_app)
    repo               = Keyword.get(opts, :repo, Module.concat([base, "Repo"]))
    table              = Keyword.get(opts, :table, "users")
    binary_id          = opts[:binary_id]
    migration_defaults = migration_defaults(attrs)
    {assocs, attrs}    = partition_attrs(attrs)
    indexes            = indexes(table, attrs)

    %{
      repo: repo,
      table: table,
      binary_id: binary_id,
      attrs: attrs,
      migration_defaults: migration_defaults,
      assocs: assocs,
      indexes: indexes
    }
  end

  template =
    """
    defmodule <%= inspect schema.repo %>.Migrations.Create<%= Macro.camelize(schema.table) %> do
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

  defp schema_migration(schema) do
    EEx.eval_string(unquote(template), schema: schema)
  end
end
