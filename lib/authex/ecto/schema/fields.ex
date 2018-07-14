defmodule Authex.Ecto.Schema.Fields do
  @moduledoc """
  Handles the Ecto schema fields for user.
  """
  alias Authex.{Config, Ecto.Schema}

  @attrs [
    {:password_hash, :string},
    {:current_password, :string, virtual: true},
    {:password, :string, virtual: true},
    {:password_confirm, :string, virtual: true},
  ]

  @spec attrs(Config.t()) :: [tuple()]
  def attrs(config) do
    login_field = Schema.login_field(config)

    [{login_field, :string, null: false}]
    |> Enum.concat(@attrs)
  end

  @spec indexes(Config.t()) :: [tuple()]
  def indexes(config) do
    login_field = Schema.login_field(config)

    [{login_field, true}]
  end
end
