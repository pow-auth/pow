defmodule Pow.Extension.Phoenix.RoutesTest do
  defmodule Phoenix.Routes do
    def a_path(_conn), do: "/first"
    def b_path(_conn), do: "/second"
  end

  defmodule Routes do
    use Pow.Extension.Phoenix.Routes,
      extensions: [Pow.Extension.Phoenix.RoutesTest]

    def pow_extension_phoenix_routes_test_a_path(_conn), do: "/overridden"
  end

  use ExUnit.Case
  doctest Pow.Extension.Phoenix.Routes

  test "can override routes" do
    assert Routes.pow_extension_phoenix_routes_test_a_path(nil) == "/overridden"
    assert Routes.pow_extension_phoenix_routes_test_b_path(nil) == "/second"
  end

  test "has fallback module" do
    assert Routes.Pow.Extension.Phoenix.RoutesTest.Phoenix.Routes.a_path(nil) == "/overridden"
  end
end
