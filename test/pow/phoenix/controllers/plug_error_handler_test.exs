defmodule Pow.Phoenix.PlugErrorHandlerTest do
  use ExUnit.Case
  doctest Pow.Phoenix.PlugErrorHandler

  import Phoenix.ConnTest, except: [get_flash: 2]
  import Pow.Test.Phoenix.ConnCase, only: [get_flash: 2]

  alias Plug.Conn
  alias Pow.Phoenix.{Messages, PlugErrorHandler}

  defmodule Messages do
    use Pow.Phoenix.Messages

    def user_not_authenticated(_conn), do: :not_authenticated
    def user_already_authenticated(_conn), do: :already_authenticated
  end

  defp prepare_conn(conn) do
    conn
    |> Conn.put_private(:pow_config, messages_backend: Messages)
    |> Conn.put_private(:phoenix_flash, %{}) # TODO: Remove when Phoenix 1.7 is required
    |> Map.update(:assigns, %{}, & Map.put(&1, :flash, %{}))
    |> Conn.put_private(:phoenix_router, Pow.Test.Phoenix.Router)
    |> Conn.fetch_query_params()
  end

  setup do
    conn = prepare_conn(build_conn())

    {:ok, conn: conn}
  end

  test "call/2 :not_authenticated", %{conn: conn} do
    conn = PlugErrorHandler.call(conn, :not_authenticated)

    assert redirected_to(conn) == "/session/new?request_path=%2F"
    assert get_flash(conn, :error) == :not_authenticated
  end

  test "call/2 :not_authenticated doesn't override flash if message is nil", %{conn: conn} do
    conn =
      conn
      |> Conn.put_private(:pow_config, [])
      |> Phoenix.Controller.put_flash(:error, "Existing error")
      |> PlugErrorHandler.call(:not_authenticated)

    assert redirected_to(conn) == "/session/new?request_path=%2F"
    assert get_flash(conn, :error) == "Existing error"
  end

  test "call/2 :not_authenticated doesn't set request_path if not GET request" do
    conn =
      :post
      |> build_conn("/", nil)
      |> prepare_conn()
      |> PlugErrorHandler.call(:not_authenticated)

    assert redirected_to(conn) == "/session/new"
    assert get_flash(conn, :error) == :not_authenticated

    conn =
      :delete
      |> build_conn("/", nil)
      |> prepare_conn()
      |> PlugErrorHandler.call(:not_authenticated)

    assert redirected_to(conn) == "/session/new"
    assert get_flash(conn, :error) == :not_authenticated
  end

  test "call/2 :already_authenticated", %{conn: conn} do
    conn = PlugErrorHandler.call(conn, :already_authenticated)

    assert redirected_to(conn) == "/"
    assert get_flash(conn, :error) == :already_authenticated
  end
end
