defmodule Pow.Test.Extension.Phoenix.Router.Phoenix.Router do
  use Pow.Extension.Phoenix.Router.Base

  def routes(_config) do
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

defmodule Pow.Extension.Phoenix.RouterTest do
  use Pow.Test.Ecto.TestCase
  doctest Pow.Extension.Phoenix.Router

  alias Pow.Test.Extension.Phoenix.Router.Helpers, as: Routes
  alias Phoenix.ConnTest

  @conn ConnTest.build_conn()

  test "has routes" do
    assert unquote(Routes.pow_session_path(@conn, :new)) == "/session/new"
    assert unquote(Routes.pow_test_path(@conn, :new)) = "/test/new"
  end
end
