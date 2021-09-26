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

    test "with halt {:halt, conn} from before_process", %{conn: conn} do
      defmodule HaltsBeforeProcess do
        use Pow.Extension.Phoenix.ControllerCallbacks.Base

        def before_process(SessionController, :new, conn, _config) do
          {:halt, Conn.halt(conn)}
        end

        def before_respond(SessionController, :new, _, _config) do
          raise "Should not be called"
        end
      end

      conn =
        conn
        |> Conn.put_private(:pow_config, user: User, controller_callbacks: HaltsBeforeProcess)
        |> Conn.put_private(:phoenix_action, :new)

      conn = Controller.action(SessionController, conn, %{})

      assert conn.halted
    end

    test "{:halt, conn} from before_respond", %{conn: conn} do
      defmodule HaltsBeforeRespond do
        use Pow.Extension.Phoenix.ControllerCallbacks.Base

        def before_respond(SessionController, :new, {:ok, _changeset, conn}, _config) do
          {:halt, Conn.halt(conn)}
        end
      end

      conn =
        conn
        |> Conn.put_private(:pow_config, user: User, controller_callbacks: HaltsBeforeRespond)
        |> Conn.put_private(:phoenix_action, :new)

      conn = Controller.action(SessionController, conn, %{})

      assert conn.halted
    end
  end
end
