defmodule Authex.Plug.RequireNotAuthenticatedTest do
  use ExUnit.Case
  doctest Authex.Plug.RequireNotAuthenticated

  alias Plug.Conn
  alias Authex.{Plug, Plug.RequireNotAuthenticated}
  alias Authex.Test.ConnHelpers

  setup do
    conn = :get
           |> ConnHelpers.conn("/")
           |> Plug.put_config([current_user_assigns_key: :current_user])

    {:ok, %{conn: conn}}
  end

  defmodule ErrorHandler do
    def call(conn, :already_authenticated) do
      Conn.put_private(conn, :authenticated, true)
    end
  end

  @default_config [error_handler: __MODULE__.ErrorHandler]

  test "call/2", %{conn: conn} do
    conn = RequireNotAuthenticated.call(conn, @default_config)

    refute conn.private[:authenticated]
    refute conn.halted
  end

  test "call/2 with assigned user", %{conn: conn} do
    conn = conn
           |> Plug.assign_current_user("user", [])
           |> RequireNotAuthenticated.call(@default_config)

    assert conn.private[:authenticated]
    assert conn.halted
  end
end
