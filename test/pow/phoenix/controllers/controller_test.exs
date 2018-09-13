defmodule Pow.Phoenix.ControllerTest do
  use Pow.Test.Phoenix.ConnCase
  alias Plug.Conn
  alias Pow.Phoenix.{Controller, LayoutView, SessionController, SessionView, ViewHelpers}
  alias Pow.Test.{Ecto.Users.User, Phoenix, Phoenix.Endpoint, Phoenix.Router}

  describe "action/3" do
    test "using `:web_module`", %{conn: conn} do
      conn =
        conn
        |> Conn.put_private(:pow_config, web_module: Phoenix, user: User)
        |> Conn.put_private(:phoenix_view, SessionView)
        |> Conn.put_private(:phoenix_router, Router)
        |> Conn.put_private(:phoenix_action, :new)
        |> Conn.put_private(:phoenix_endpoint, Endpoint)
        |> Conn.put_private(:phoenix_layout, {LayoutView, :app})
        |> Conn.assign(:action, "#")

      conn = ViewHelpers.layout(conn)
      conn = Controller.action(SessionController, conn, %{})

      assert html = html_response(conn, 200)
      assert html =~ ":web_module new session"
    end
  end
end
