defmodule Pow.Ecto.Schema.ModuleTest do
  use ExUnit.Case
  doctest Pow.Ecto.Schema.Module

  alias Pow.Ecto.Schema.Module

  test "new/4" do
    schema = Module.new(Pow, "Users.User", "users")

    assert schema.module == Pow.Users.User
    refute schema.binary_id

    schema = Module.new(Test, "Organizations.Organization", "organizations", binary_id: true)

    assert schema.module == Test.Organizations.Organization
    assert schema.binary_id
  end

  test "gen/1" do
    content = Module.gen(Module.new(Pow, "Users.User", "users"))

    assert content =~ "defmodule Pow.Users.User do"
    assert content =~ "use Pow.Ecto.Schema"
    assert content =~ "schema \"users\" do"
    assert content =~ "pow_user_fields()"

    content = Module.gen(Module.new(Pow, "Users.User", "users", user_id_field: :username))
    assert content =~ "use Pow.Ecto.Schema, user_id_field: :username"

    content = Module.gen(Module.new(Test, "Users.User", "users"))
    assert content =~ "defmodule Test.Users.User do"
  end
end
