defmodule Pow.Test.Ecto.Users.UsernameUser do
  @moduledoc false
  use Ecto.Schema
  use Pow.Ecto.Schema,
    user_id_field: :username

  schema "users" do
    pow_user_fields()
    timestamps()
  end
end
