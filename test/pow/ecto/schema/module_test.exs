defmodule Pow.Ecto.Schema.ModuleTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema.Module

  alias Pow.Ecto.Schema.Module

  test "gen/1" do
    content = Module.gen(Pow)

    assert content =~ "defmodule Pow.Users.User do"
    assert content =~ "use Pow.Ecto.Schema"
    assert content =~ "schema \"users\" do"
    assert content =~ "pow_user_fields()"

    content = Module.gen(Pow, user_id_field: :username)
    assert content =~ "use Pow.Ecto.Schema, user_id_field: :username"

    content = Module.gen(Test)
    assert content =~ "defmodule Test.Users.User do"
  end
end
