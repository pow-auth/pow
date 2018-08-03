defmodule Pow.Phoenix.PlugErrorHandlerTest do
  use ExUnit.Case
  doctest Pow.Phoenix.PlugErrorHandler

  alias Phoenix.ConnTest
  alias Plug.Conn
  alias Pow.Phoenix.{Messages, PlugErrorHandler}

  defmodule Messages do
    use Pow.Phoenix.Messages

    def user_not_authenticated(_conn), do: :not_authenticated
    def user_already_authenticated(_conn), do: :already_authenticated
  end

  setup do
    conn =
      ConnTest.build_conn()
      |> Conn.put_private(:pow_config, messages_backend: Messages)
      |> Conn.put_private(:phoenix_flash, %{})
      |> Conn.put_private(:phoenix_router, Pow.Test.Phoenix.Router)
      |> Conn.fetch_query_params()

    {:ok, conn: conn}
  end

  test "call/2 :not_autenticated", %{conn: conn} do
    conn = PlugErrorHandler.call(conn, :not_authenticated)

    assert ConnTest.redirected_to(conn) == "/session/new?request_path=%2F"
    assert ConnTest.get_flash(conn, :error) == :not_authenticated
  end

  test "call/2 :already_authenticated", %{conn: conn} do
    conn = PlugErrorHandler.call(conn, :already_authenticated)

    assert ConnTest.redirected_to(conn) == "/"
    assert ConnTest.get_flash(conn, :error) == :already_authenticated
  end
end
