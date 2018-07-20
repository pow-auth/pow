defmodule Pow.Ecto.Schema.Module do
  @moduledoc """
  Generates schema module content.
  """
  alias Pow.Config

  @template """
    defmodule <%= inspect schema.module %> do
      use Ecto.Schema
      use Pow.Ecto.Schema<%= if schema.login_field do %>, login_field: <%= inspect(schema.login_field) %><% end %>

    <%= if schema.binary_id do %>
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id<% end %>
      schema <%= inspect schema.table %> do
        pow_user_fields()

        timestamps()
      end
    end
    """

  @spec gen(binary(), Config.t()) :: binary()
  def gen(context_base, config \\ []) do
    context_base
    |> parse_options(config)
    |> schema_module()
  end

  defp parse_options(base, config) do
    module      = Module.concat([base, "Users", "User"])
    table       = Config.get(config, :table, "users")
    binary_id   = config[:binary_id]
    login_field = config[:login_field]

    %{
      module: module,
      table: table,
      binary_id: binary_id,
      login_field: login_field
    }
  end

  defp schema_module(schema) do
    EEx.eval_string(unquote(@template), schema: schema)
  end
end
