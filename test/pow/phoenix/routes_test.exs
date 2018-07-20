defmodule Pow.Phoenix.RoutesTest do
  defmodule CustomRoutes do
    use Pow.Phoenix.Routes

    def after_sign_in_path(_conn), do: "/custom"
  end

  use Pow.Test.Phoenix.ConnCase
  doctest Pow.Phoenix.Routes
  alias Pow.Phoenix.Routes

  setup %{conn: conn} do
    conn = Plug.Conn.put_private(conn, :phoenix_router, Pow.Test.Phoenix.Router)

    {:ok, conn: conn}
  end

  test "can customize routes", %{conn: conn} do
    assert Routes.after_sign_in_path(conn) == "/"
    assert Routes.after_sign_out_path(conn) == "/session/new"

    assert CustomRoutes.after_sign_in_path(conn) == "/custom"
    assert CustomRoutes.after_sign_out_path(conn) == "/session/new"
  end
end
