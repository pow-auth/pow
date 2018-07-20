defmodule Pow.Plug.RequireAuthenticatedTest do
  use ExUnit.Case
  doctest Pow.Plug.RequireAuthenticated

  alias Plug.Conn
  alias Pow.{Plug, Plug.RequireAuthenticated}
  alias Pow.Test.ConnHelpers

  setup do
    conn = :get
           |> ConnHelpers.conn("/")
           |> Plug.put_config([current_user_assigns_key: :current_user])

    {:ok, %{conn: conn}}
  end

  defmodule ErrorHandler do
    def call(conn, :not_authenticated) do
      Conn.put_private(conn, :not_authenticated, true)
    end
  end

  @default_config [error_handler: __MODULE__.ErrorHandler]

  test "call/2", %{conn: conn} do
    conn = RequireAuthenticated.call(conn, @default_config)

    assert conn.private[:not_authenticated]
    assert conn.halted
  end

  test "call/2 with assigned user", %{conn: conn} do
    conn = conn
           |> Plug.assign_current_user("user", [])
           |> RequireAuthenticated.call(@default_config)

    refute conn.private[:not_authenticated]
    refute conn.halted
  end
end
