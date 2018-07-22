defmodule Pow.Ecto.Schema.Fields do
  @moduledoc """
  Handles the Ecto schema fields for user.
  """
  alias Pow.{Config, Ecto.Schema}

  @attrs [
    {:password_hash, :string},
    {:current_password, :string, virtual: true},
    {:password, :string, virtual: true},
    {:confirm_password, :string, virtual: true},
  ]

  @spec attrs(Config.t()) :: [tuple()]
  def attrs(config) do
    user_id_field = Schema.user_id_field(config)

    [{user_id_field, :string, null: false}]
    |> Enum.concat(@attrs)
  end

  @spec indexes(Config.t()) :: [tuple()]
  def indexes(config) do
    user_id_field = Schema.user_id_field(config)

    [{user_id_field, true}]
  end
end
