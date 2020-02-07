defmodule Pow.Plug.RequireAuthenticatedTest do
  use ExUnit.Case
  doctest Pow.Plug.RequireAuthenticated

  alias Plug.{Conn, Test}
  alias Pow.{Config.ConfigError, Plug, Plug.RequireAuthenticated}

  setup do
    conn =
      :get
      |> Test.conn("/")
      |> Plug.put_config(current_user_assigns_key: :current_user)

    {:ok, %{conn: conn}}
  end

  defmodule ErrorHandler do
    def call(conn, :not_authenticated) do
      Conn.put_private(conn, :not_authenticated, true)
    end
  end

  @default_config [error_handler: __MODULE__.ErrorHandler]

  test "init/1 requires error handler" do
    assert_raise ConfigError, "No :error_handler configuration option provided. It's required to set this when using Pow.Plug.RequireAuthenticated.", fn ->
      RequireAuthenticated.init([])
    end
  end

  test "call/2", %{conn: conn} do
    opts = RequireAuthenticated.init(@default_config)
    conn = RequireAuthenticated.call(conn, opts)

    assert conn.private[:not_authenticated]
    assert conn.halted
  end

  test "call/2 with assigned user", %{conn: conn} do
    opts = RequireAuthenticated.init(@default_config)
    conn =
      conn
      |> Plug.assign_current_user("user", [])
      |> RequireAuthenticated.call(opts)

    refute conn.private[:not_authenticated]
    refute conn.halted
  end
end
