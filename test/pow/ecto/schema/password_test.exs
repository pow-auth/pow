defmodule Pow.Ecto.Schema.PasswordTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema.Password

  alias Pow.Ecto.Schema.Password

  @password "secret"

  test "pbkdf2_hash/1" do
    assert [algo, iterations, _salt, _hash] = String.split(Password.pbkdf2_hash(@password, []), "$", trim: true)

    assert algo == "pbkdf2-sha512"
    assert iterations == "100000"
  end

  test "pbkdf2_verify/1" do
    hash = Password.pbkdf2_hash(@password)
    assert Password.pbkdf2_verify(@password, hash)
  end
end
