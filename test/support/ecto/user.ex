defmodule Authex.Test.Ecto.Users.User do
  use Ecto.Schema
  use Authex.Ecto.Schema

  schema "users" do
    field :custom, :string

    user_fields()

    timestamps()
  end
end
