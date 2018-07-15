defmodule Authex.Test.Ecto.Users.UsernameUser do
  use Ecto.Schema
  use Authex.Ecto.Schema, login_field: :username

  schema "users" do
    authex_user_fields()
    timestamps()
  end
end
