defmodule Pow.Test.Extension.Phoenix.Router.Phoenix.Router do
  use Pow.Extension.Phoenix.Router.Base

  defmacro routes(_config) do
    quote location: :keep do
      resources "/test", TestController, only: [:new, :create, :edit, :update]
    end
  end
end

defmodule Pow.Test.Extension.Phoenix.Router do
  use Phoenix.Router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router,
    extensions: [Pow.Test.Extension.Phoenix.Router]

  scope "/" do
    pow_routes()
    pow_extension_routes()
  end
end

module_raised_with =
  try do
    defmodule Pow.Test.Extension.Phoenix.RouterAliasScope do
      @moduledoc false
      use Phoenix.Router
      use Pow.Phoenix.Router
      use Pow.Extension.Phoenix.Router,
        extensions: [Pow.Test.Extension.Phoenix.Router]

      scope "/", Test do
        pow_extension_routes()
      end
    end
  rescue
    e in ArgumentError -> e.message
  else
    _ -> raise "Scope with alias didn't throw any error"
  end


defmodule Pow.Extension.Phoenix.RouterTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Extension.Phoenix.Router

  alias Pow.Test.Extension.Phoenix.Router.Helpers, as: Routes
  alias Phoenix.ConnTest

  @conn ConnTest.build_conn()

  test "has routes" do
    assert unquote(Routes.pow_session_path(@conn, :new)) == "/session/new"
    assert unquote(Routes.pow_test_extension_phoenix_router_test_path(@conn, :new)) = "/test/new"
  end

  test "validates no aliases" do
    assert unquote(module_raised_with) =~ "Pow routes should not be defined inside scopes with aliases: Test"
    assert unquote(module_raised_with) =~ "scope \"/\", Test do"
  end
end
