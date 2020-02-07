defmodule Pow.Plug.RequireNotAuthenticatedTest do
  use ExUnit.Case
  doctest Pow.Plug.RequireNotAuthenticated

  alias Plug.{Conn, Test}
  alias Pow.{Config.ConfigError, Plug, Plug.RequireNotAuthenticated}

  setup do
    conn =
      :get
      |> Test.conn("/")
      |> Plug.put_config(current_user_assigns_key: :current_user)

    {:ok, %{conn: conn}}
  end

  defmodule ErrorHandler do
    def call(conn, :already_authenticated) do
      Conn.put_private(conn, :authenticated, true)
    end
  end

  @default_config [error_handler: __MODULE__.ErrorHandler]

  test "init/1 requires error handler" do
    assert_raise ConfigError, "No :error_handler configuration option provided. It's required to set this when using Pow.Plug.RequireNotAuthenticated.", fn ->
      RequireNotAuthenticated.init([])
    end
  end

  test "call/2", %{conn: conn} do
    opts = RequireNotAuthenticated.init(@default_config)
    conn = RequireNotAuthenticated.call(conn, opts)

    refute conn.private[:authenticated]
    refute conn.halted
  end

  test "call/2 with assigned user", %{conn: conn} do
    opts = RequireNotAuthenticated.init(@default_config)
    conn =
      conn
      |> Plug.assign_current_user("user", [])
      |> RequireNotAuthenticated.call(opts)

    assert conn.private[:authenticated]
    assert conn.halted
  end
end
