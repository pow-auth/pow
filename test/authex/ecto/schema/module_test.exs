defmodule Authex.Ecto.Schema.ModuleTest do
  use ExUnit.Case
  doctest Authex.Ecto.Schema.Module

  alias Authex.Ecto.Schema.Module

  test "gen/1" do
    content = Module.gen(Authex)

    assert content =~ "defmodule Authex.Users.User do"
    assert content =~ "use Authex.Ecto.Schema"
    assert content =~ "schema \"users\" do"
    assert content =~ "user_fields()"

    content = Module.gen(Authex, login_field: :username)
    assert content =~ "use Authex.Ecto.Schema, login_field: :username"

    content = Module.gen(Test)
    assert content =~ "defmodule Test.Users.User do"
  end
end
