defmodule PowTest.Phoenix.TestView do
  def render(_template, _opts), do: :ok
end

defmodule Pow.Test.Phoenix.PowTest.TestView do
  def render(_template, _opts), do: :ok
end

defmodule Pow.Phoenix.ViewHelpersTest do
  use Pow.Test.Phoenix.ConnCase
  doctest Pow.Phoenix.ViewHelpers

  alias Plug.Conn
  alias Pow.Phoenix.ViewHelpers
  alias Pow.Test.Ecto.Users.User

  setup %{conn: conn} do
    conn =
      conn
      |> Map.put(:params, %{"_format" => "html"})
      |> Conn.put_private(:pow_config, [])
      |> Conn.put_private(:phoenix_endpoint, Pow.Test.Phoenix.Endpoint)
      |> Conn.put_private(:phoenix_view, Pow.Phoenix.SessionView)
      |> Conn.put_private(:phoenix_layout, {Pow.Phoenix.LayoutView, :app})
      |> Conn.put_private(:phoenix_router, Pow.Test.Phoenix.Router)
      |> Conn.assign(:changeset, User.changeset(%User{}, %{}))
      |> Conn.assign(:action, "/")

    {:ok, conn: conn}
  end

  test "layout/1", %{conn: conn} do
    conn = ViewHelpers.layout(conn)

    assert conn.private[:phoenix_endpoint] == Pow.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Pow.Phoenix.SessionView
    assert conn.private[:phoenix_layout] == {Pow.Test.Phoenix.LayoutView, :app}
  end

  test "layout/1 with `:web_module`", %{conn: conn} do
    conn =
      conn
      |> Conn.put_private(:pow_config, web_module: Pow.Test.Phoenix)
      |> ViewHelpers.layout()

    assert conn.private[:phoenix_endpoint] == Pow.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Pow.Test.Phoenix.Pow.SessionView
    assert conn.private[:phoenix_layout] == {Pow.Test.Phoenix.LayoutView, :app}
  end

  test "layout/1 in extension", %{conn: conn} do
    conn =
      conn
      |> Conn.put_private(:phoenix_view, PowTest.Phoenix.TestView)
      |> ViewHelpers.layout()

    assert conn.private[:phoenix_endpoint] == Pow.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == PowTest.Phoenix.TestView
    assert conn.private[:phoenix_layout] == {Pow.Test.Phoenix.LayoutView, :app}
  end

  test "layout/1 in extension with `:web_module`", %{conn: conn} do
    conn =
      conn
      |> Conn.put_private(:phoenix_view, PowTest.Phoenix.TestView)
      |> Conn.put_private(:pow_config, web_module: Pow.Test.Phoenix)
      |> ViewHelpers.layout()

    assert conn.private[:phoenix_endpoint] == Pow.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Pow.Test.Phoenix.PowTest.TestView
    assert conn.private[:phoenix_layout] == {Pow.Test.Phoenix.LayoutView, :app}
  end

  test "layout/1 with no layout", %{conn: conn} do
    conn =
      conn
      |> Phoenix.Controller.put_layout(false)
      |> ViewHelpers.layout()

    assert conn.private[:phoenix_endpoint] == Pow.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Pow.Phoenix.SessionView
    assert conn.private[:phoenix_layout] == false
  end

  test "layout/1 with custom layout", %{conn: conn} do
    conn =
      conn
      |> Phoenix.Controller.put_layout({MyAppWeb.LayoutView, :custom})
      |> ViewHelpers.layout()

    assert conn.private[:phoenix_endpoint] == Pow.Test.Phoenix.Endpoint
    assert conn.private[:phoenix_view] == Pow.Phoenix.SessionView
    assert conn.private[:phoenix_layout] == {MyAppWeb.LayoutView, :custom}
  end
end
