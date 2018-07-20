defmodule Pow.Ecto.SchemaTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema

  alias Pow.Test.Ecto.Users.{User, UsernameUser}

  test "user_schema/1" do
    user = %User{}

    assert Map.has_key?(user, :email)
    assert Map.has_key?(user, :current_password)
    refute Map.has_key?(user, :username)

    user = %UsernameUser{}
    assert Map.has_key?(user, :username)
    refute Map.has_key?(user, :email)
  end
end
