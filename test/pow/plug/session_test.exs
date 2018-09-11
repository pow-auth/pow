defmodule Pow.Plug.SessionTest do
  use ExUnit.Case
  doctest Pow.Plug.Session

  alias Plug.Conn
  alias Pow.{Config, Plug, Plug.Session, Store.CredentialsCache}
  alias Pow.Test.ConnHelpers

  @ets Pow.Test.EtsCacheMock
  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: @ets
  ]

  setup do
    @ets.init()
    conn =
      :get
      |> ConnHelpers.conn("/")
      |> ConnHelpers.init_session()

    {:ok, %{conn: conn, ets: @ets}}
  end

  test "call/2 sets mod in :pow_config", %{conn: conn} do
    opts = Session.init(@default_opts)
    conn = Session.call(conn, opts)

    assert is_nil(conn.assigns[:current_user])
    assert conn.private[:pow_config] == Config.put(@default_opts, :mod, Session)
  end

  test "call/2 with assigned current_user", %{conn: conn} do
    opts = Session.init(@default_opts)
    conn =
      conn
      |> Plug.assign_current_user("assigned", @default_opts)
      |> Session.call(opts)

    assert conn.assigns[:current_user] == "assigned"
  end

  test "call/2 with stored current_user", %{conn: conn, ets: ets} do
    ets.put(nil, "token", {"cached", :os.system_time(:millisecond)})

    opts = Session.init(@default_opts)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "token")
      |> Session.call(opts)

    assert conn.assigns[:current_user] == "cached"
  end

  test "call/2 with non existing cached key", %{conn: conn, ets: ets} do
    ets.put(nil, "token", "cached")

    opts = Session.init(@default_opts)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "invalid")
      |> Session.call(opts)

    assert is_nil(conn.assigns[:current_user])
  end

  test "call/2 creates new session when :session_renewal_ttl reached", %{conn: conn, ets: ets} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    timestamp       = :os.system_time(:millisecond)
    stale_timestamp = timestamp - ttl - 1
    init_conn       =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], "token")

    ets.put(nil, "token", {"cached", timestamp})

    opts = Session.init(config)
    conn = Session.call(init_conn, opts)
    session_id = get_session_id(conn)

    assert conn.assigns[:current_user] == "cached"

    ets.put(nil, "token", {"cached", stale_timestamp})

    conn = Session.call(init_conn, opts)

    assert conn.assigns[:current_user] == "cached"
    assert new_session_id = get_session_id(conn)
    assert new_session_id != session_id
  end

  test "call/2 with prepended `:otp_app` session key", %{conn: conn, ets: ets} do
    ets.put(nil, "token", {"cached", :os.system_time(:millisecond)})

    opts =
      @default_opts
      |> Keyword.delete(:session_key)
      |> Keyword.put(:otp_app, :test_app)
      |> Session.init()
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session("test_app_auth", "token")
      |> Session.call(opts)

    assert conn.assigns[:current_user] == "cached"
  end

  test "call/2 with prepended `:namespace` session key", %{conn: conn, ets: ets} do
    ets.put(nil, "token", {"cached", :os.system_time(:millisecond)})

    opts =
      @default_opts
      |> Keyword.delete(:session_key)
      |> Keyword.put(:namespace, :test)
      |> Session.init()
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session("test_auth", "token")
      |> Session.call(opts)

    assert conn.assigns[:current_user] == "cached"
  end

  test "call/2 with multiple `:namespace` configurations", %{conn: conn} do
    opts = Session.init(@default_opts)
    conn = Session.call(conn, opts ++ [namespace: :user])
    conn = Session.call(conn, opts ++ [namespace: :admin])

    assert conn.private[:pow_config_user]
    assert conn.private[:pow_config_admin]
  end

  test "create/2 creates new session id", %{conn: conn, ets: ets} do
    user = %{id: 1}
    opts = Session.init(@default_opts)
    conn =
      conn
      |> Session.call(opts)
      |> Session.do_create(user, opts)

    session_id = get_session_id(conn)
    {etc_user, _inserted_at} = ets.get(nil, session_id)

    assert is_binary(session_id)
    assert etc_user == user
    assert Plug.current_user(conn) == user

    conn = Session.do_create(conn, user, opts)
    new_session_id = get_session_id(conn)
    {etc_user, _inserted_at} = ets.get(nil, new_session_id)

    assert is_binary(session_id)
    assert new_session_id != session_id
    assert ets.get(nil, session_id) == :not_found
    assert etc_user == user
    assert Plug.current_user(conn) == user
  end

  test "create/2 creates new session id with `:otp_app` prepended", %{conn: conn} do
    opts =
      @default_opts
      |> Keyword.delete(:session_key)
      |> Keyword.put(:otp_app, :test_app)
      |> Session.init()
    conn =
      conn
      |> Session.call(opts)
      |> Session.do_create(%{id: 1}, opts)

    refute get_session_id(conn)

    session_id = conn.private[:plug_session]["test_app_auth"]
    assert String.starts_with?(session_id, "test_app_")
  end

  test "delete/1 removes session id", %{conn: conn, ets: ets} do
    user = %{id: 1}
    opts = Session.init(@default_opts)
    conn =
      conn
      |> Session.call(opts)
      |> Session.do_create(user, opts)

    session_id = get_session_id(conn)
    {etc_user, _inserted_at} = ets.get(nil, session_id)

    assert is_binary(session_id)
    assert etc_user == user
    assert Plug.current_user(conn) == user

    conn = Session.do_delete(conn, opts)

    refute new_session_id = get_session_id(conn)
    assert is_nil(new_session_id)
    assert ets.get(nil, session_id) == :not_found
    assert is_nil(Plug.current_user(conn))
  end

  describe "with EtsCache backend" do
    test "stores through CredentialsCache", %{conn: conn} do
      sesion_key = "auth"
      config     = [session_key: sesion_key]
      token      = "credentials_cache_test"
      timestamp  = :os.system_time(:millisecond)
      CredentialsCache.put(config, token, {"cached", timestamp})

      :timer.sleep(100)

      opts = Session.init(session_key: "auth")
      conn =
        conn
        |> Conn.fetch_session()
        |> Conn.put_session("auth", token)
        |> Session.call(opts)

      assert conn.assigns[:current_user] == "cached"
    end
  end

  def get_session_id(conn) do
    conn.private[:plug_session][@default_opts[:session_key]]
  end
end
