defmodule Pow.Ecto.Schema.Module do
  @moduledoc """
  Generates schema module content.

  ## Configuration options

    * `:table` - the ecto table name, defaults to "users".

    * `:binary_id` - if the schema module should use binary id, default nil.

    * `:user_id_field` - the user id field to use in the schema module,
      defaults nil.
  """
  alias Pow.Config

  @template """
    defmodule <%= inspect schema.module %> do
      use Ecto.Schema
      use Pow.Ecto.Schema<%= if schema.user_id_field do %>, user_id_field: <%= inspect(schema.user_id_field) %><% end %>

    <%= if schema.binary_id do %>
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id<% end %>
      schema <%= inspect schema.table %> do
        pow_user_fields()

        timestamps()
      end
    end
    """

  @doc """
  Generates schema module file content.
  """
  @spec gen(atom(), Config.t()) :: binary()
  def gen(context_base, config \\ []) do
    context_base
    |> parse_options(config)
    |> schema_module()
  end

  defp parse_options(base, config) do
    module        = Module.concat([base, "Users", "User"])
    table         = Config.get(config, :table, "users")
    binary_id     = config[:binary_id]
    user_id_field = config[:user_id_field]

    %{
      module: module,
      table: table,
      binary_id: binary_id,
      user_id_field: user_id_field
    }
  end

  defp schema_module(schema) do
    EEx.eval_string(unquote(@template), schema: schema)
  end
end
