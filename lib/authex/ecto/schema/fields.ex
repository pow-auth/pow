defmodule Authex.Ecto.Schema.Fields do
  @moduledoc """
  Handles the Ecto schema fields for user.
  """
  @attrs [
    {:password_hash, :string},
    {:current_password, :string, virtual: true},
    {:password, :string, virtual: true},
    {:password_confirm, :string, virtual: true},
  ]

  @spec attrs(atom()) :: [tuple()]
  def attrs(login_field) do
    [{login_field, :string, null: false}]
    |> Enum.concat(@attrs)
  end
end
