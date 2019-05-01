module_raised_with =
  try do
    defmodule Pow.Test.Phoenix.RouterAliasScope do
      @moduledoc false
      use Phoenix.Router
      use Pow.Phoenix.Router

      scope "/", Test do
        pow_routes()
      end
    end
  rescue
    e in ArgumentError -> e.message
  else
    _ -> raise "Scope with alias didn't throw any error"
  end

defmodule Pow.Phoenix.RouterTest do
  use ExUnit.Case
  doctest Pow.Phoenix.Router

  test "validates no aliases" do
    assert unquote(module_raised_with) =~ "Pow routes should not be defined inside scopes with aliases: Test"
    assert unquote(module_raised_with) =~ "scope \"/\", Test do"
  end
end
