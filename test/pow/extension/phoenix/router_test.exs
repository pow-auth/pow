defmodule Pow.Extension.Phoenix.RouterTest do
  # Implementation needed for `Pow.Extension.Base.has?/2` check
  defmodule ExtensionMock do
    use Pow.Extension.Base

    @impl true
    def phoenix_router?(), do: true
  end

  # To prevent the `TestController.init/1 is undefined` warnings
  defmodule ExtensionMock.Phoenix.TestController do
    use Phoenix.Controller, namespace: Pow.Extension.Phoenix.RouterTest
  end

  defmodule ExtensionMock.Phoenix.Router do
    use Pow.Extension.Phoenix.Router.Base

    alias Pow.Phoenix.Router

    @impl true
    defmacro routes(_config) do
      quote location: :keep do
        Router.pow_resources "/test", TestController, only: [:new, :create, :edit, :update, :delete]
      end
    end
  end

  defmodule Router do
    use Phoenix.Router
    use Pow.Phoenix.Router
    use Pow.Extension.Phoenix.Router,
      extensions: [Pow.Extension.Phoenix.RouterTest.ExtensionMock]

    scope "/", ExtensionMock.Phoenix, as: "pow_extension_phoenix_router_test_extension_mock" do
      get "/test/:id/overridden", TestController, :edit
      resources "/overridden/test", TestController, only: [:delete]
    end

    scope "/" do
      pow_routes()
      pow_extension_routes()
    end

    def phoenix_routes, do: @phoenix_routes
  end

  module_raised_with =
    try do
      defmodule RouterAliasScope do
        @moduledoc false
        use Phoenix.Router
        use Pow.Phoenix.Router
        use Pow.Extension.Phoenix.Router,
          extensions: [Pow.Extension.Phoenix.RouterTest.ExtensionMock]

        scope "/", Test do
          pow_extension_routes()
        end
      end
    rescue
      e in ArgumentError -> e.message
    else
      _ -> raise "Scope with alias didn't throw any error"
    end

  use Pow.Test.Ecto.TestCase
  doctest Pow.Extension.Phoenix.Router

  alias Phoenix.ConnTest
  alias Router.Helpers, as: Routes

  @conn ConnTest.build_conn()

  test "has routes" do
    assert Enum.count(Router.phoenix_routes()) == 15

    assert unquote(Routes.pow_session_path(@conn, :new)) == "/session/new"
    assert unquote(Routes.pow_extension_phoenix_router_test_extension_mock_test_path(@conn, :new)) == "/test/new"
  end

  test "validates no aliases" do
    assert unquote(module_raised_with) =~ "Pow routes should not be defined inside scopes with aliases: Test"
    assert unquote(module_raised_with) =~ "scope \"/\", Test do"
  end

  test "can override routes" do
    assert Enum.count(Router.phoenix_routes(), &(&1.plug == ExtensionMock.Phoenix.TestController)) == 6

    assert unquote(Routes.pow_extension_phoenix_router_test_extension_mock_test_path(@conn, :edit, 1)) == "/test/1/overridden"
    assert Enum.count(Router.phoenix_routes(), &(&1.plug == ExtensionMock.Phoenix.TestController && &1.plug_opts == :edit)) == 1

    assert unquote(Routes.pow_extension_phoenix_router_test_extension_mock_test_path(@conn, :delete, 1)) == "/overridden/test/1"
    assert Enum.count(Router.phoenix_routes(), &(&1.plug == ExtensionMock.Phoenix.TestController && &1.plug_opts == :delete)) == 1
  end
end
