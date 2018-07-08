defmodule Authex.Authorization.Plug.SessionTest do
  use ExUnit.Case
  doctest Authex

  alias Authex.Authorization.{Plug, Plug.Session}
  alias Authex.Test.{ConnHelpers, CredentialsCacheMock}

  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    session_store: CredentialsCacheMock,
    credentials_cache_name: "credentials",
    credentials_cache_ttl: :timer.hours(48)
  ]

  setup do
    CredentialsCacheMock.init()
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
    CredentialsCacheMock.create(nil, "token", "cached")

    conn = conn
           |> ConnHelpers.put_session(@default_opts[:session_key], "token")
           |> Session.call(@default_opts)

    assert conn.assigns[:current_user] == "cached"
  end

  test "call/2 with non existing cached key", %{conn: conn} do
    CredentialsCacheMock.create(nil, "token", "cached")

    conn = conn
           |> ConnHelpers.put_session(@default_opts[:session_key], "invalid")
           |> Session.call(@default_opts)

    assert is_nil(conn.assigns[:current_user])
  end

  test "create/2 creates new session id", %{conn: conn} do
    user = %{id: 1}
    conn = conn
           |> Session.call(@default_opts)
           |> Session.create(user)

    assert session_id = get_session_id(conn)
    assert is_binary(session_id)
    assert CredentialsCacheMock.get(nil, session_id) == user
    assert Plug.current_user(conn) == user

    conn = Session.create(conn, user)
    assert new_session_id = get_session_id(conn)
    assert is_binary(session_id)

    assert new_session_id != session_id
    assert CredentialsCacheMock.get(nil, session_id) == :not_found
    assert CredentialsCacheMock.get(nil, new_session_id) == user
    assert Plug.current_user(conn) == user
  end

  test "delete/1 removes session id", %{conn: conn} do
    user = %{id: 1}
    conn = conn
           |> Session.call(@default_opts)
           |> Session.create(user)

    assert session_id = get_session_id(conn)
    assert is_binary(session_id)
    assert CredentialsCacheMock.get(nil, session_id) == user
    assert Plug.current_user(conn) == user

    conn = Session.delete(conn)

    refute new_session_id = get_session_id(conn)
    assert is_nil(new_session_id)
    assert CredentialsCacheMock.get(nil, session_id) == :not_found
    assert is_nil(Plug.current_user(conn))
  end

  def get_session_id(conn) do
    conn.private[:plug_session][@default_opts[:session_key]]
  end
end
