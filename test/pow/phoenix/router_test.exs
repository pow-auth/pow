module_raised_with =
  try do
    defmodule Pow.Test.Phoenix.RouterAliasScope do
      @moduledoc false
      use Phoenix.Router, helpers: false
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

defmodule Pow.Test.Phoenix.OverriddenRouteRouter do
  @moduledoc false

  use Phoenix.Router, helpers: false
  use Pow.Phoenix.Router

  scope "/", Pow.Phoenix, as: "pow" do
    get "/registration/overridden", RegistrationController, :new
    resources "/registration/overridden", RegistrationController, only: [:edit], singleton: true
  end

  scope "/:extra" do
    pow_routes()
  end

  scope "/" do
    pow_routes()
  end

  def phoenix_routes, do: @phoenix_routes
end

defmodule Pow.Phoenix.RouterTest do
  use ExUnit.Case
  doctest Pow.Phoenix.Router

  alias Pow.Test.Phoenix.OverriddenRouteRouter

  test "validates no aliases" do
    assert unquote(module_raised_with) =~ "Pow routes should not be defined inside scopes with aliases: Test"
    assert unquote(module_raised_with) =~ "scope \"/\", Test do"
  end

  test "can override routes" do
    assert [route_1, route_2] = filter_routes(Pow.Phoenix.RegistrationController, :new)
    assert route_1.path == "/:extra/registration/new"
    assert route_2.path == "/registration/overridden"

    assert [route_1, route_2] = filter_routes(Pow.Phoenix.RegistrationController, :edit)
    assert route_1.path == "/:extra/registration/edit"
    assert route_2.path == "/registration/overridden/edit"
  end

  defp filter_routes(plug, opts) do
    Enum.filter(OverriddenRouteRouter.phoenix_routes(), & &1.plug == plug && &1.plug_opts == opts)
  end
end
