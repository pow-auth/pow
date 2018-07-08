defmodule Authex.Authorization.Plug.SessionTest do
  use ExUnit.Case
  doctest Authex

  alias Authex.Authorization.{Plug, Plug.Session}
  alias Authex.Test.ConnHelpers

  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    session_store: __MODULE__.CredentialsCacheMock,
    credentials_cache_name: "credentials",
    credentials_cache_ttl: :timer.hours(48)
  ]

  defmodule CredentialsCacheMock do
    def get(_config, "token"), do: "cached"
    def get(_config, _token), do: :not_found

    def delete(_config, _token), do: nil

    def create(_config, _token, _value), do: nil
  end

  setup do
    conn = :get |> ConnHelpers.conn("/") |> ConnHelpers.with_session()

    {:ok, %{conn: conn}}
  end

  test "call/2", %{conn: conn} do
    conn = Session.call(conn, @default_opts)

    assert is_nil(conn.assigns[:current_user])
    assert conn.private[:authex_config] == Keyword.put(@default_opts, :mod, Session)
  end

  test "call/2 with assigned current_user", %{conn: conn} do
    conn = conn
           |> Plug.assign_current_user("assigned", @default_opts)
           |> Session.call(@default_opts)

    assert conn.assigns[:current_user] == "assigned"
  end

  test "call/2 with stored current_user", %{conn: conn} do
    conn = conn
           |> ConnHelpers.put_session(@default_opts[:session_key], "token")
           |> Session.call(@default_opts)

    assert conn.assigns[:current_user] == "cached"
  end

  test "call/2 with non existing cached key", %{conn: conn} do
    conn = conn
           |> ConnHelpers.put_session(@default_opts[:session_key], "invalid")
           |> Session.call(@default_opts)

    assert is_nil(conn.assigns[:current_user])
  end

  test "create/2 creates new session id", %{conn: conn} do
    conn = conn
           |> Session.call(@default_opts)
           |> Session.create(%{id: 1})

    session_id = conn.private[:plug_session]

    assert session_id != %{}

    conn = Session.create(conn, %{id: 1})

    assert conn.private[:plug_session] != session_id
  end

  test "delete/1 removes session id", %{conn: conn} do
    conn = conn
           |> Session.call(@default_opts)
           |> Session.create(%{id: 1})

    assert conn.private[:plug_session] != %{}

    conn = Session.delete(conn)

    assert conn.private[:plug_session] == %{}
  end
end
