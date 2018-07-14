defmodule Authex.Phoenix.ViewHelpersTest do
  use Authex.Test.Phoenix.ConnCase
  doctest Authex

  alias Authex.Phoenix.ViewHelpers
  alias Authex.Test.UsersContextMock
  alias Plug.Conn

  setup %{conn: conn} do
    changeset   = UsersContextMock.changeset([], %{})
    action      = "/"
    conn =
      conn
      |> Map.put(:params, %{"_format" => "html"})
      |> Conn.put_private(:authex_config, [])
      |> Conn.put_private(:phoenix_endpoint, Authex.Test.Phoenix.Endpoint)
      |> Conn.put_private(:phoenix_view, Authex.Phoenix.SessionView)
      |> Conn.put_private(:phoenix_layout, {Authex.Phoenix.LayoutView, :app})
      |> Conn.put_private(:phoenix_router, Authex.Test.Phoenix.Router)
      |> Conn.assign(:changeset, changeset)
      |> Conn.assign(:action, action)

    {:ok, %{conn: conn}}
  end

  test "render/3", %{conn: conn} do
    conn = ViewHelpers.render(conn, :new)

    assert conn.private[:phoenix_endpoint] == Authex.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Authex.Phoenix.SessionView
    assert conn.private[:phoenix_layout] == {Authex.Test.Phoenix.LayoutView, :app}
  end

  test "render/3 with :web_module", %{conn: conn} do
    conn =
      conn
      |> Conn.put_private(:authex_config, [web_module: Authex.Test.Phoenix])
      |> ViewHelpers.render(:new)

    assert conn.private[:phoenix_endpoint] == Authex.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Authex.Test.Phoenix.Authex.SessionView
    assert conn.private[:phoenix_layout] == {Authex.Test.Phoenix.LayoutView, :app}
  end
end
