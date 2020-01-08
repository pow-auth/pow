defmodule Pow.Plug.SessionTest do
  use ExUnit.Case
  doctest Pow.Plug.Session

  alias Plug.{Conn, Test}
  alias Pow.{Plug, Plug.Session, Store.Backend.EtsCache, Store.CredentialsCache}
  alias Pow.Test.{ConnHelpers, Ecto.Users.User, EtsCacheMock}

  @default_opts [
    current_user_assigns_key: :current_user,
    session_key: "auth",
    cache_store_backend: EtsCacheMock
  ]
  @store_config [backend: EtsCacheMock]
  @user %User{id: 1}

  setup do
    EtsCacheMock.init()

    conn =
      :get
      |> ConnHelpers.conn("/")
      |> ConnHelpers.init_session()

    {:ok, %{conn: conn}}
  end

  test "call/2 sets plug in :pow_config", %{conn: conn} do
    opts = Session.init(@default_opts)
    conn = Session.call(conn, opts)
    expected_config = [mod: Session, plug: Session] ++ @default_opts

    assert is_nil(conn.assigns[:current_user])
    assert conn.private[:pow_config] == expected_config
  end

  test "call/2 with assigned current_user", %{conn: conn} do
    opts = Session.init(@default_opts)
    conn =
      conn
      |> Plug.assign_current_user("assigned", @default_opts)
      |> Session.call(opts)

    assert conn.assigns[:current_user] == "assigned"
  end

  test "call/2 with stored current_user", %{conn: conn} do
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: :os.system_time(:millisecond), fingerprint: "fingerprint"})

    opts = Session.init(@default_opts)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "token")
      |> Session.call(opts)

    assert conn.assigns[:current_user] == @user
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 with stored session and custom metadata", %{conn: conn} do
    inserted_at = :os.system_time(:millisecond)
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: inserted_at, a: 1})

    opts = Session.init(@default_opts)
    conn =
      conn
      |> Conn.put_private(:pow_session_metadata, b: 2)
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "token")
      |> Session.call(opts)

    assert conn.assigns[:current_user] == @user
    assert conn.private[:pow_session_metadata][:inserted_at] == inserted_at
    assert conn.private[:pow_session_metadata][:a] == 1
  end

  test "call/2 with non existing cached key", %{conn: conn} do
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: :os.system_time(:millisecond)})

    opts = Session.init(@default_opts)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@default_opts[:session_key], "invalid")
      |> Session.call(opts)

    assert is_nil(conn.assigns[:current_user])
  end

  test "call/2 creates new session when :session_renewal_ttl reached", %{conn: conn} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    timestamp       = :os.system_time(:millisecond)
    stale_timestamp = timestamp - ttl - 1
    init_conn       =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], "token")

    CredentialsCache.put(@store_config, "token", {@user, inserted_at: timestamp, fingerprint: "fingerprint"})

    opts = Session.init(config)
    conn = Session.call(init_conn, opts)
    session_id = get_session_id(conn)

    assert conn.assigns[:current_user] == @user

    CredentialsCache.put(@store_config, "token", {@user, inserted_at: stale_timestamp, fingerprint: "fingerprint"})
    CredentialsCache.put(@store_config, "newer_token", {@user, inserted_at: timestamp, fingerprint: "new_fingerprint"})

    conn = Session.call(init_conn, opts)

    assert conn.assigns[:current_user] == @user
    assert new_session_id = get_session_id(conn)
    assert new_session_id != session_id
    assert {_user, metadata} = CredentialsCache.get(@store_config, new_session_id)
    assert metadata[:inserted_at] != stale_timestamp
    assert metadata[:fingerprint] == "fingerprint"
    assert conn.private[:pow_session_metadata][:fingerprint] == "fingerprint"
  end

  test "call/2 with prepended `:otp_app` session key", %{conn: conn} do
    CredentialsCache.put(@store_config, "token", {@user, inserted_at: :os.system_time(:millisecond)})

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

    assert conn.assigns[:current_user] == @user
  end

  # TODO: Remove by 1.1.0
  test "backwards compatible", %{conn: conn} do
    ttl             = 100
    config          = Keyword.put(@default_opts, :session_ttl_renewal, ttl)
    stale_timestamp = :os.system_time(:millisecond) - ttl - 1

    @store_config
    |> Keyword.put(:namespace, "credentials")
    |> EtsCacheMock.put({"token", {@user, stale_timestamp}})

    opts = Session.init(config)
    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(config[:session_key], "token")
      |> Session.call(opts)

    assert new_session_id = get_session_id(conn)
    assert new_session_id != "token"

    assert conn.assigns[:current_user] == @user
  end

  describe "create/2" do
    test "creates new session id", %{conn: conn} do
      opts = Session.init(@default_opts)
      conn =
        conn
        |> Session.call(opts)
        |> Session.do_create(@user, opts)

      session_id = get_session_id(conn)

      assert {@user, metadata} = CredentialsCache.get(@store_config, session_id)
      assert is_binary(session_id)
      assert Plug.current_user(conn) == @user
      assert metadata[:inserted_at]
      assert metadata[:fingerprint]

      conn = Session.do_create(conn, @user, opts)
      new_session_id = get_session_id(conn)

      assert {@user, new_metadata} = CredentialsCache.get(@store_config, new_session_id)
      assert is_binary(session_id)
      assert new_session_id != session_id
      assert CredentialsCache.get(@store_config, session_id) == :not_found
      assert Plug.current_user(conn) == @user
      assert metadata[:fingerprint] == new_metadata[:fingerprint]
    end

    test "renews plug session", %{conn: new_conn} do
      opts = Session.init(@default_opts)
      conn =
        new_conn
        |> Session.call(opts)
        |> Session.do_create(@user, opts)
        |> Conn.send_resp(200, "")

      assert %{"foobar" => %{value: plug_session_id}} = conn.resp_cookies

      conn =
        new_conn
        |> Test.recycle_cookies(conn)
        |> Session.call(opts)
        |> Session.do_create(@user, opts)
        |> Conn.send_resp(200, "")

      assert %{"foobar" => %{value: new_plug_session_id}} = conn.resp_cookies

      refute plug_session_id == new_plug_session_id
    end

    test "creates with custom metadata", %{conn: conn} do
      inserted_at = :os.system_time(:millisecond) - 10
      opts = Session.init(@default_opts)
      conn =
        conn
        |> Conn.put_private(:pow_session_metadata, inserted_at: inserted_at, a: 1)
        |> Session.call(opts)
        |> Session.do_create(@user, opts)

      assert conn.assigns[:current_user] == @user
      assert conn.private[:pow_session_metadata][:inserted_at] != inserted_at
      assert conn.private[:pow_session_metadata][:fingerprint]
      assert conn.private[:pow_session_metadata][:a] == 1
    end

    test "creates new session id with `:otp_app` prepended", %{conn: conn} do
      opts =
        @default_opts
        |> Keyword.delete(:session_key)
        |> Keyword.put(:otp_app, :test_app)
        |> Session.init()
      conn =
        conn
        |> Session.call(opts)
        |> Session.do_create(@user, opts)

      refute get_session_id(conn)

      session_id = conn.private[:plug_session]["test_app_auth"]
      assert String.starts_with?(session_id, "test_app_")
    end
  end

  test "delete/1 removes session id", %{conn: conn} do
    opts = Session.init(@default_opts)
    conn =
      conn
      |> Session.call(opts)
      |> Session.do_create(@user, opts)

    session_id = get_session_id(conn)

    assert {@user, _metadata} = CredentialsCache.get(@store_config, session_id)
    assert is_binary(session_id)
    assert Plug.current_user(conn) == @user

    conn = Session.do_delete(conn, opts)

    refute new_session_id = get_session_id(conn)
    assert is_nil(new_session_id)
    assert CredentialsCache.get(@store_config, session_id) == :not_found
    assert is_nil(Plug.current_user(conn))
  end

  describe "with EtsCache backend" do
    setup do
      start_supervised!({EtsCache, []})

      :ok
    end

    test "call/2", %{conn: conn} do
      sesion_key = "auth"
      config     = [session_key: sesion_key]
      token      = "credentials_cache_test"
      timestamp  = :os.system_time(:millisecond)
      CredentialsCache.put(config, token, {@user, inserted_at: timestamp})

      :timer.sleep(100)

      opts = Session.init(session_key: "auth")
      conn =
        conn
        |> Conn.fetch_session()
        |> Conn.put_session("auth", token)
        |> Session.call(opts)

      assert conn.assigns[:current_user] == @user
    end
  end

  def get_session_id(conn) do
    conn.private[:plug_session][@default_opts[:session_key]]
  end
end
