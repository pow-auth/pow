defmodule Authex.Test.Ecto.Users.User do
  use Ecto.Schema
  use Authex.Ecto.Schema

  schema "users" do
    field :custom, :string

    authex_user_fields()

    timestamps()
  end

  def changeset(user_or_changeset, params) do
    user_or_changeset
    |> authex_changeset(params)
    |> Ecto.Changeset.cast(params, [:custom])
  end
end
