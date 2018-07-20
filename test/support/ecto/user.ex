defmodule Pow.Test.Ecto.Users.User do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema

  schema "users" do
    field :custom, :string

    pow_user_fields()

    timestamps()
  end

  def changeset(user_or_changeset, params) do
    user_or_changeset
    |> pow_changeset(params)
    |> Ecto.Changeset.cast(params, [:custom])
  end
end
