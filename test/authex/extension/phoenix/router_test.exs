defmodule Authex.Test.Extension.Phoenix.Router.Phoenix.Router do
  def routes(_config) do
    quote location: :keep do
      resources "/test", TestController, only: [:new, :create, :edit, :update]
    end
  end
end

defmodule Authex.Test.Extension.Phoenix.Router do
  use Phoenix.Router
  use Authex.Phoenix.Router
  use Authex.Extension.Phoenix.Router,
    extensions: [Authex.Test.Extension.Phoenix.Router]

  scope "/" do
    authex_routes()
    authex_extension_routes()
  end
end

defmodule Authex.Extension.Phoenix.RouterTest do
  use Authex.Test.Ecto.TestCase
  doctest Authex.Extension.Phoenix.Router

  alias Authex.Test.Extension.Phoenix.Router.Helpers, as: Routes
  alias Phoenix.ConnTest

  @conn ConnTest.build_conn()

  test "has routes" do
    assert unquote(Routes.authex_session_path(@conn, :new)) == "/session/new"
    assert unquote(Routes.authex_test_path(@conn, :new)) = "/test/new"
  end
end
