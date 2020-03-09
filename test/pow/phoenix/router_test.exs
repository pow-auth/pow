defmodule Pow.Phoenix.RouterTest do
  use ExUnit.Case
  doctest Pow.Phoenix.Router

  alias Phoenix.ConnTest

  test "validates no aliases" do
    contents =
      quote do
        use Phoenix.Router
        use Pow.Phoenix.Router

        scope "/", Test do
          pow_routes()
        end
      end

    assert_raise ArgumentError,
      """
      Pow routes should not be defined inside scopes with aliases: Test

      Please consider separating your scopes:

        scope "/" do
          pipe_through :browser

          pow_routes()
        end

        scope "/", Test do
          pipe_through :browser

          get "/", PageController, :index
        end
      """,
      fn ->
        Module.create(__MODULE__.RouterAliasScope, contents, __ENV__)
      end
  end

  test "can override routes" do
    contents =
      quote do
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

    Module.create(__MODULE__.OverriddenRouteRouter, contents, __ENV__)

    contents =
      quote do
        alias unquote(__MODULE__).OverriddenRouteRouter
        alias unquote(__MODULE__).OverriddenRouteRouter.Helpers, as: Routes

        @conn ConnTest.build_conn()

        assert Routes.pow_registration_path(@conn, :new) == "/registration/overridden"
        assert Routes.pow_registration_path(@conn, :new, "test") == "/test/registration/new"
        assert Enum.count(OverriddenRouteRouter.phoenix_routes(), &(&1.plug == Pow.Phoenix.RegistrationController && &1.plug_opts == :new)) == 2

        assert Routes.pow_registration_path(@conn, :edit) == "/registration/overridden/edit"
        assert Routes.pow_registration_path(@conn, :edit, "test") == "/test/registration/edit"
        assert Enum.count(OverriddenRouteRouter.phoenix_routes(), &(&1.plug == Pow.Phoenix.RegistrationController && &1.plug_opts == :edit)) == 2
      end

    Module.create(__MODULE__.OverriddenRouteRouterTest, contents, __ENV__)
  end
end
