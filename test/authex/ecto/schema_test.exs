defmodule Authex.Ecto.SchemaTest do
  use ExUnit.Case
  doctest Authex.Ecto.Schema

  alias Authex.Test.Ecto.Users.{User, UsernameUser}

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
