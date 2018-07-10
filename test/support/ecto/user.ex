defmodule Authex.Test.Ecto.Users.User do
  use Ecto.Schema
  require Authex.Ecto.UserSchema

  schema "users" do
    field :username, :string

    Authex.Ecto.UserSchema.user_schema()

    timestamps()
  end
end
