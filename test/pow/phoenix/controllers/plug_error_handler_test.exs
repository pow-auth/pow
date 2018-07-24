defmodule Pow.Phoenix.PlugErrorHandlerTest do
  use ExUnit.Case
  doctest Pow.Phoenix.PlugErrorHandler

  alias Phoenix.ConnTest
  alias Plug.Conn
  alias Pow.Phoenix.{Messages, PlugErrorHandler}

  @not_authenticated_message Messages.user_not_authenticated(nil)
  @already_authenticated_message Messages.user_already_authenticated(nil)

  setup do
    conn =
      ConnTest.build_conn()
      |> Conn.put_private(:pow_config, [])
      |> Conn.put_private(:phoenix_flash, %{})
      |> Conn.put_private(:phoenix_router, Pow.Test.Phoenix.Router)
      |> Conn.fetch_query_params()

    {:ok, conn: conn}
  end

  test "call/2 :not_autenticated", %{conn: conn} do
    conn = PlugErrorHandler.call(conn, :not_authenticated)

    assert ConnTest.redirected_to(conn) == "/session/new?request_path=%2F"
    assert ConnTest.get_flash(conn, :error) == @not_authenticated_message
  end

  test "call/2 :already_authenticated", %{conn: conn} do
    conn = PlugErrorHandler.call(conn, :already_authenticated)

    assert ConnTest.redirected_to(conn) == "/"
    assert ConnTest.get_flash(conn, :error) == @already_authenticated_message
  end
end
