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

defmodule Pow.Test.Phoenix.OverriddenRouteRouter do
  @moduledoc false

  use Phoenix.Router
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

  alias Phoenix.ConnTest
  alias Pow.Test.Phoenix.OverriddenRouteRouter.Helpers, as: OverriddenRoutes

  @conn ConnTest.build_conn()

  test "validates no aliases" do
    assert unquote(module_raised_with) =~ "Pow routes should not be defined inside scopes with aliases: Test"
    assert unquote(module_raised_with) =~ "scope \"/\", Test do"
  end

  test "can override routes" do
    assert unquote(OverriddenRoutes.pow_registration_path(@conn, :new)) == "/registration/overridden"
    assert unquote(OverriddenRoutes.pow_registration_path(@conn, :new, "test")) == "/test/registration/new"
    assert Enum.count(Pow.Test.Phoenix.OverriddenRouteRouter.phoenix_routes(), &(&1.plug == Pow.Phoenix.RegistrationController && &1.plug_opts == :new)) == 2

    assert unquote(OverriddenRoutes.pow_registration_path(@conn, :edit)) == "/registration/overridden/edit"
    assert unquote(OverriddenRoutes.pow_registration_path(@conn, :edit, "test")) == "/test/registration/edit"
    assert Enum.count(Pow.Test.Phoenix.OverriddenRouteRouter.phoenix_routes(), &(&1.plug == Pow.Phoenix.RegistrationController && &1.plug_opts == :edit)) == 2
  end
end
